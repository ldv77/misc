#!/bin/bash

# WARNING! EXTREMELY DANGEROUS!!! DO NOT TURN IT ON IN PRODUCTION!!!
# WARNING! EXTREMELY DANGEROUS!!! DO NOT TURN IT ON IN PRODUCTION!!!
# WARNING! EXTREMELY DANGEROUS!!! DO NOT TURN IT ON IN PRODUCTION!!!
# For script's debugging purpose ONLY.
# 'yes' / anything
declare -g -r CLEAR_EXISTING_INSTALL='yes'

# 'yes' / anything
declare -g -r DO_INITIAL_UPDATE='yes'

# 'distrib' / 'latest' / 'none'
declare -g -r VERSION_DESIRED_MARIADB='distrib'


declare -g -r PDNS_API_KEY='CHANGEMECHANGEMECHANGEME'

declare -g -r PDA_DIR='/opt/web/powerdns-admin'


# 'yes' / anything
declare -g -r INITIATE_PDNS_DB='yes'

# 'yes' / anything
declare -g -r INITIATE_PDA_DB='yes'

declare -g -r MYSQL_ADMIN_USER='root'
declare -g -r MYSQL_ADMIN_PASSWD='CHANGEMECHANGEMECHANGEME'

declare -g -r PDNS_DB_NAME='powerdns'
declare -g -r PDNS_DB_HOST='localhost'
declare -g -r PDNS_DB_USER='pdnsuser'
declare -g -r PDNS_DB_PASSWD='CHANGEMECHANGEMECHANGEME'
declare -g -r PDNS_DB_USERFROM='127.0.0.1'

declare -g -r PDA_DB_NAME='pdnsadmin'
declare -g -r PDA_DB_HOST='localhost'
declare -g -r PDA_DB_USER='pdnsadminuser'
declare -g -r PDA_DB_PASSWD='CHANGEMECHANGEMECHANGEME'
declare -g -r PDA_DB_USERFROM='127.0.0.1'



