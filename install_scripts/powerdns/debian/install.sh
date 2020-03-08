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


src () {
    # Let's enhance 'source' functionality slightly.
    if [[ $# -ne 2 ]]; then
        die "Unexpected number of arguments."
    else
        local f_inc_file_name="$1"
        local f_inc_file_desc="$2"

        if [[ ! -f "${f_inc_file_name}" ]]; then
            die "Error: Unable to stat ${f_inc_file_desc} as regular file at \"${f_inc_file_name}\""
        elif [[ ! -r "${f_inc_file_name}" ]]; then
            die "Error: Unable to read ${f_inc_file_desc} at \"${f_inc_file_name}\""
        else
            source "${f_inc_file_name}" \
                || die "Error: unable to load \"${f_inc_file_name}\" as ${f_inc_file_desc}."
        fi
    fi
}


# Is our shell fresh enough?
BASH_MAJOR_VERSION=$(echo "${BASH_VERSION}" | cut --delimiter='.' --fields=1) \
    || die "Unable to get bash major version."
if [[ ${BASH_MAJOR_VERSION} -lt 4 ]]; then
    die "Shell is too old: bash version 4 or newer is required."
fi

# Are we root?
if [[ $EUID -ne 0 ]]; then
    die "Current job is configured to run under 'root' credentials. Use 'sudo' or something."
fi

# Get script absolute path.
declare -r MY_PATH=$(cd "$( dirname "${BASH_SOURCE[0]}")" && pwd ) || die "Can't get script directory."

# Get task configuration.
src "${MY_PATH}/config.sh" "Task configuration"

# TODO Check if empty vars.


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


# PowerDNS database.
if [[ "${INITIATE_PDNS_DB:-}" == "yes" ]]; then
    echo -e "\n--- --- --- Initiating PowerDNS database."

    if [[ "${CLEAR_EXISTING_INSTALL:-}" == "yes" ]]; then
        echo "(DEBUGGING) Clearing previously configured DB."

        echo "DROP USER IF EXISTS '${PDNS_DB_USER}'@'${PDNS_DB_USERFROM}';" \
            | mysql --host="${PDNS_DB_HOST}" --user="${MYSQL_ADMIN_USER}" --password="${MYSQL_ADMIN_PASSWD}"

        echo "DROP DATABASE IF EXISTS ${PDNS_DB_NAME};" \
            | mysql --host="${PDNS_DB_HOST}" --user="${MYSQL_ADMIN_USER}" --password="${MYSQL_ADMIN_PASSWD}"

    fi

    echo "CREATE DATABASE ${PDNS_DB_NAME} CHARACTER SET utf8 COLLATE utf8_general_ci;" \
        | mysql --host="${PDNS_DB_HOST}" --user="${MYSQL_ADMIN_USER}" --password="${MYSQL_ADMIN_PASSWD}"

    echo "CREATE USER '${PDNS_DB_USER}'@'${PDNS_DB_USERFROM}';" \
        | mysql --host="${PDNS_DB_HOST}" --user="${MYSQL_ADMIN_USER}" --password="${MYSQL_ADMIN_PASSWD}"

    echo "SET PASSWORD FOR '${PDNS_DB_USER}'@'${PDNS_DB_USERFROM}' = PASSWORD('${PDNS_DB_PASSWD}');" \
        | mysql --host="${PDNS_DB_HOST}" --user="${MYSQL_ADMIN_USER}" --password="${MYSQL_ADMIN_PASSWD}"

    echo "GRANT ALL PRIVILEGES ON ${PDNS_DB_NAME}.* TO '${PDNS_DB_USER}'@'${PDNS_DB_USERFROM}';" \
        | mysql --host="${PDNS_DB_HOST}" --user="${MYSQL_ADMIN_USER}" --password="${MYSQL_ADMIN_PASSWD}"

    echo "FLUSH PRIVILEGES;" \
        | mysql --host="${PDNS_DB_HOST}" --user="${MYSQL_ADMIN_USER}" --password="${MYSQL_ADMIN_PASSWD}"

    pv "${MY_PATH}/sql01.sql" | mysql --host="${PDNS_DB_HOST}" --user="${MYSQL_ADMIN_USER}" --password="${MYSQL_ADMIN_PASSWD}" --database="${PDNS_DB_NAME}"

else
    echo -e "\n--- --- --- PowerDNS database initiating is prohibited by configuration."

fi


# Install PowerDNS and configure DB parameters.
echo -e "\n--- --- --- Installing PowerDNS."
apt-get -y install pdns-server pdns-backend-mysql


cp "${MY_PATH}/etc/powerdns/pdns.d/pdns.local.gmysql.conf" "/etc/powerdns/pdns.d/"


echo -e "\n--- --- --- Installing dnsutils for testing, curl and finally PowerDNS-Admin."
apt-get -y install python3-dev dnsutils curl
apt-get -y install -y default-libmysqlclient-dev python-mysqldb libsasl2-dev libffi-dev libldap2-dev libssl-dev libxml2-dev libxslt1-dev libxmlsec1-dev pkg-config

curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo 'deb https://dl.yarnpkg.com/debian/ stable main' > /etc/apt/sources.list.d/yarn.list

# needed for https repo
apt-get -y install apt-transport-https
apt-get update 
apt-get -y install yarn


echo -e "\n--- --- --- Cloning PowerDNS-Admin itself."

if [[ "${CLEAR_EXISTING_INSTALL:-}" == "yes" ]]; then
    echo "(DEBUGGING) Clearing previously cloned \"${PDA_DIR}\"."
    rm -rf "${PDA_DIR}"
fi

git clone "https://github.com/ngoduykhanh/PowerDNS-Admin.git" "${PDA_DIR}/"

cd "${PDA_DIR}/"

echo -e "\n--- --- --- Creating virtual environment for flask?"
pip install virtualenv
virtualenv -p python3 flask
. ./flask/bin/activate

echo -e "\n--- --- --- Installing dependencies via pip."
pip install -r requirements.txt


if [[ "${INITIATE_PDA_DB:-}" == "yes" ]]; then
    echo -e "\n--- --- --- Setting up PowerDNS-Admin database."

    if [[ "${CLEAR_EXISTING_INSTALL:-}" == "yes" ]]; then
        echo "(DEBUGGING) Clearing previously configured DB."

        echo "DROP USER IF EXISTS '${PDA_DB_USER}'@'${PDA_DB_USERFROM}';" \
            | mysql --host="${PDA_DB_HOST}" --user="${MYSQL_ADMIN_USER}" --password="${MYSQL_ADMIN_PASSWD}"

        echo "DROP DATABASE IF EXISTS ${PDA_DB_NAME};" \
            | mysql --host="${PDA_DB_HOST}" --user="${MYSQL_ADMIN_USER}" --password="${MYSQL_ADMIN_PASSWD}"
    fi

    echo "CREATE DATABASE ${PDA_DB_NAME} CHARACTER SET utf8 COLLATE utf8_general_ci;" \
        | mysql --host="${PDA_DB_HOST}" --user="${MYSQL_ADMIN_USER}" --password="${MYSQL_ADMIN_PASSWD}"

    echo "CREATE USER '${PDA_DB_USER}'@'${PDA_DB_USERFROM}';" \
        | mysql --host="${PDA_DB_HOST}" --user="${MYSQL_ADMIN_USER}" --password="${MYSQL_ADMIN_PASSWD}"

    echo "SET PASSWORD FOR '${PDA_DB_USER}'@'${PDA_DB_USERFROM}' = PASSWORD('${PDA_DB_PASSWD}');" \
        | mysql --host="${PDA_DB_HOST}" --user="${MYSQL_ADMIN_USER}" --password="${MYSQL_ADMIN_PASSWD}"

    echo "GRANT ALL PRIVILEGES ON ${PDA_DB_NAME}.* TO '${PDA_DB_USER}'@'${PDA_DB_USERFROM}';" \
        | mysql --host="${PDA_DB_HOST}" --user="${MYSQL_ADMIN_USER}" --password="${MYSQL_ADMIN_PASSWD}"

    echo "FLUSH PRIVILEGES;" \
        | mysql --host="${PDA_DB_HOST}" --user="${MYSQL_ADMIN_USER}" --password="${MYSQL_ADMIN_PASSWD}"

else
    echo -e "\n--- --- --- PowerDNS-Admin database setting up is prohibited by configuration."

fi

cp "${MY_PATH}/opt/web/powerdns-admin/powerdnsadmin/default_config.py" "${PDA_DIR}/powerdnsadmin/default_config.py"
export FLASK_APP=powerdnsadmin/__init__.py
flask db upgrade
flask db migrate -m "Init DB"


echo -e "\n--- --- --- Installing nodejs/yarn."
curl -sL https://deb.nodesource.com/setup_12.x | bash -
apt-get install -y nodejs
yarn install --pure-lockfile

echo -e "\n--- --- --- Building assets with flask."
flask assets build


echo -e "\n--- --- --- Making systemd unit."
if [[ "${CLEAR_EXISTING_INSTALL:-}" == "yes" ]]; then
    echo "(DEBUGGING) Clearing previously created unit runtime dir."
    rm -rf "${PDA_RUNTIME_DIR}"
fi

mkdir -p "${PDA_RUNTIME_DIR}"
chown pdns:pdns "${PDA_RUNTIME_DIR}"


cp "${MY_PATH}/etc/systemd/system/powerdns-admin.service" "/etc/systemd/system/"
systemctl daemon-reload

echo -e "\n--- --- --- Starting \"powerdns-admin\" service."
systemctl enable powerdns-admin
systemctl start powerdns-admin
systemctl status powerdns-admin

echo -e "\n--- --- --- Configuring nginx site."
apt-get -y install nginx
cp "${MY_PATH}/powerdns-admin.conf" "/etc/nginx/sites-enabled/"
chown -R pdns:pdns "${PDA_DIR}/powerdnsadmin/static/"
nginx -t && systemctl restart nginx

echo -e "\n--- --- --- Configuring PowerDNS API."
echo 'api=yes' >> '/etc/powerdns/pdns.conf'
echo "api-key=${PDNS_API_KEY}" >> '/etc/powerdns/pdns.conf'
echo 'webserver=yes' >> '/etc/powerdns/pdns.conf'
echo "webserver-address=0.0.0.0" >> '/etc/powerdns/pdns.conf'
echo 'webserver-allow-from=0.0.0.0/0,::/0' >> '/etc/powerdns/pdns.conf'
echo 'webserver-port=8081' >> '/etc/powerdns/pdns.conf'

echo -e "\n--- --- --- Restarting \"pdns\" service."
systemctl enable pdns
systemctl restart pdns
systemctl status pdns

echo "All done."

# now go to server_name url and create a firt user account that will be admin
# log in
# configure api access on powerdns-admin
# enjoy

