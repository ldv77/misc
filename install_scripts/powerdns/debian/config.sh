#!/bin/bash

# WARNING! EXTREMELY DANGEROUS!!! DO NOT TURN IT ON IN PRODUCTION!!!
# WARNING! EXTREMELY DANGEROUS!!! DO NOT TURN IT ON IN PRODUCTION!!!
# WARNING! EXTREMELY DANGEROUS!!! DO NOT TURN IT ON IN PRODUCTION!!!
# For script's debugging purpose ONLY.
# 'yes' / anything
declare -r CLEAR_EXISTING_INSTALL='yes'

# 'yes' / anything
declare -r DO_INITIAL_UPDATE='yes'

# 'distrib' / 'latest' / 'none'
declare -r VERSION_DESIRED_MARIADB='distrib'

# 'yes' / anything
declare -r INITIATE_PDNS_DB='yes'

# 'yes' / anything
declare -r INITIATE_PDA_DB='yes'

declare -r MYSQL_ADMIN_USER='root'
declare -r MYSQL_ADMIN_PASSWD='CHANGEMECHANGEMECHANGEME'

declare -r PDNS_DB_NAME='powerdns'
declare -r PDNS_DB_HOST='127.0.0.1'
declare -r PDNS_DB_USER='pdnsuser'
declare -r PDNS_DB_PASSWD='CHANGEMECHANGEMECHANGEME'
declare -r PDNS_DB_USERFROM='127.0.0.1'

declare -r PDA_DB_NAME='pdnsadmin'
declare -r PDA_DB_HOST='127.0.0.1'
declare -r PDA_DB_USER='pdnsadminuser'
declare -r PDA_DB_PASSWD='CHANGEMECHANGEMECHANGEME'
declare -r PDA_DB_USERFROM='127.0.0.1'



