#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail


die() {
    # For really rough situations. Don't even log. Just die. Immediately.
    local -r f_message=${1:-"DIED!"}
    echo "DYING! ${BASH_SOURCE[1]}: line ${BASH_LINENO[0]}: ${FUNCNAME[1]}: ${f_message}" >&2
    # shellcheck disable=SC2086
    exit ${2:-1}
}


BASH_MAJOR_VERSION=$(echo "${BASH_VERSION}" | cut --delimiter='.' --fields=1) \
    || die "Unable to get bash major version."
if [[ ${BASH_MAJOR_VERSION} -lt 4 ]]; then
    die "Shell is too old: bash version 4 or newer is required."
fi



# 'yes' / anything
declare -r CLEAR_EXISTING_INSTALL='yes'

# 'yes' / anything
declare -r DO_INITIAL_UPDATE='yes'

# 'distrib' / 'latest' / 'none'
declare -r VERSION_DESIRED_MARIADB='none'

# 'yes' / anything
declare -r INITIATE_PDNS_DB='yes'

# Are we root?
if [[ $EUID -ne 0 ]]; then
    die "Current job is configured to run under 'root' credentials. Use 'sudo' or something."
fi

# Get script absolute path.
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
if [ -z "$MY_PATH" ] ; then
	  die "Unable to get MY_PATH."
fi



# Upgrade system and install dependencies.
if [[ "${DO_INITIAL_UPDATE:-}" == "yes" ]]; then
    echo -e "\n--- --- --- Doing initial system upgrade."

    apt-get update && apt-get -y dist-upgrade
    apt-get -y install software-properties-common dirmngr
    apt-get -y install git pv python-pip

else
    echo -e "\n--- --- --- Initial system upgrade is prohibited by configuration."

fi


# MariaDB installation.
case "${VERSION_DESIRED_MARIADB:-}" in
    "distrib")
        echo -e "\n--- --- --- Installing MariaDB from your OS distribution."
        apt install mariadb-server
        mysql_secure_installation
        ;;

    "latest")
        echo -e "\n--- --- --- Installing latest stable MariaDB."
        die "Latest MariaDB verion installation is not yet implemented."
        #apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8
        #add-apt-repository 'deb [arch=amd64] http://mariadb.mirror.liquidtelecom.com/repo/10.4/debian buster main'
        #apt-get update && apt-get -y install mariadb-server
        #mysql_secure_installation
        ;;

    "none")
        echo -e "\n--- --- --- Installation of MariaDB is prohibited by configuration."
        ;;

    *)
        die "Unexpected value of VERSION_DESIRED_MARIADB: \"${VERSION_DESIRED_MARIADB:-}\""
        ;;

esac


echo -e "\n--- --- --- Gathering info."
echo "We need to know MariaDB root's password."
read -s -p "Enter the password: " mysql_root_password
echo


if [[ "${INITIATE_PDNS_DB:-}" == "yes" ]]; then
    echo -e "\n--- --- --- Initiating PowerDNS database."

    if [[ "${CLEAR_EXISTING_INSTALL}" == "yes" ]]; then
        echo "(DEBUGGING) Clearing previously configured DB."
        echo "DROP DATABASE powerdns;" | mysql --user="root" --password="${mysql_root_password}"
    fi

    pv "${MY_PATH}/sql01.sql" | mysql --user="root" --password="${mysql_root_password}"
else
    echo -e "\n--- --- --- PowerDNS database initiating is prohibited by configuration."
fi


# install powerdns and configure db parameters
echo -e "\n--- --- --- Installing PowerDNS."
apt-get -y install pdns-server pdns-backend-mysql


cp "${MY_PATH}/pdns.local.gmysql.conf" "/etc/powerdns/pdns.d/"

# PowerDNS DB configuration here.
vi "/etc/powerdns/pdns.d/pdns.local.gmysql.conf"


exit 1


# install dnsutils for testing, curl and finally PowerDNS-Admin
apt-get -y install python3-dev dnsutils curl
apt-get -y install -y default-libmysqlclient-dev python-mysqldb libsasl2-dev libffi-dev libldap2-dev libssl-dev libxml2-dev libxslt1-dev libxmlsec1-dev pkg-config
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo 'deb https://dl.yarnpkg.com/debian/ stable main' > /etc/apt/sources.list.d/yarn.list
apt-get -y install apt-transport-https # needed for https repo
apt-get update 
apt-get -y install yarn
git clone https://github.com/ngoduykhanh/PowerDNS-Admin.git /opt/web/powerdns-admin
cd /opt/web/powerdns-admin
pip install virtualenv
virtualenv -p python3 flask
. ./flask/bin/activate
pip install -r requirements.txt
mysql -u root -p < ${MY_PATH}/sql02.sql
vi powerdnsadmin/default_config.py
export FLASK_APP=powerdnsadmin/__init__.py
flask db upgrade
flask db migrate -m "Init DB"

# install/update nodejs, needed to use yarn
curl -sL https://deb.nodesource.com/setup_12.x | bash -
apt-get install -y nodejs
yarn install --pure-lockfile
flask assets build

# create systemd service file and activate it
mkdir /run/powerdns-admin
chown pdns:pdns /run/powerdns-admin
cp ${MY_PATH}/powerdns-admin.service /etc/systemd/system/
systemctl daemon-reload
systemctl start powerdns-admin
systemctl enable powerdns-admin
# install nginx and configure site
apt-get -y install nginx
cp ${MY_PATH}/powerdns-admin.conf /etc/nginx/sites-enabled/
chown -R pdns:pdns /opt/web/powerdns-admin/powerdnsadmin/static/
nginx -t && service nginx restart
# activate powerdns api, change api-key if needed
echo 'api=yes' >> /etc/powerdns/pdns.conf
echo 'api-key=789456123741852963' >> /etc/powerdns/pdns.conf
echo 'webserver=yes' >> /etc/powerdns/pdns.conf
echo 'webserver-address=0.0.0.0' >> /etc/powerdns/pdns.conf
echo 'webserver-allow-from=0.0.0.0/0,::/0' >> /etc/powerdns/pdns.conf
echo 'webserver-port=8081' >> /etc/powerdns/pdns.conf
service pdns restart
# now go to server_name url and create a firt user account that will be admin
# log in
# configure api access on powerdns-admin
# enjoy

