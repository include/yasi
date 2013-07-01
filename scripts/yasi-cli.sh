#! /bin/bash
# puppet-cli.sh Abstract curl
# Version - 0.4
# Date 9/12/2011 - <francisco.cabrita@gmail.com>

DATE="$(date "+%Y-%m-%d_%H:%M")"

LOGFILE="/tmp/yasi-cli-${DATE}.log"
exec > >(tee ${LOGFILE})
exec 2>&1

# CLEANUP
find /tmp/ -iname 'yasi-cli*.log' -type f -mtime +2 -exec rm {} \;

ARGS=8
E_BADARGS=65

USER="USER"
PASS="CHANGEME"

CURL_BIN="/usr/bin/curl"
CURL_OPT="--user ${USER}:${PASS} -v -i -d"

YASI_HOST="localhost"
YASI_PORT="9393"
YASI_ADDHOST_URI="/nagiosql/c/host"

ACTION=$1
HOSTNAME=$2
ADDRESS=$3
FQDN=$4
HOSTGROUP=$5
HOSTGROUPDESC=$6
SNMP_COMMUNITY=$7
SNMP_DEFAULT_COMMUNITY="snmpcommunity"
OPERATINGSYSTEM=$8

if [ -z ${SNMP_COMMUNITY} ]; then
  SNMP_COMMUNITY="${SNMP_DEFAULT_COMMUNITY}"
fi

if [ -z ${OPERATINGSYSTEM} ]; then
  OPERATINGSYSTEM="Debian"
fi

function help {
  echo ""
  echo "Usage:"
  echo "  yasi-cli.sh help"
  echo "  yasi-cli.sh addhost hostname ip fqdn hostgroup hostgroupdesc snmpcommunity operatingsystem"
  echo ""
  echo "Example:"
  echo " ./yasi-cli.sh addhost lolcat 127.0.0.1 lolcat.domain.tld lolcats \"lolcats servers\" Debian"
  echo ""
}

function addhost {

  if [ -z ${HOSTNAME} ]; then
    echo "Insert hostname please!"
    exit 1;
  elif [ -z ${ADDRESS} ]; then
    echo "Insert address please!"
    exit 1;
  elif [ -z ${FQDN} ]; then
    echo "Insert FQDN please!"
    exit 1;
  elif [ -z ${HOSTGROUP} ]; then
    echo "Insert hostgroup"
    exit 1;
  elif [ -z "${HOSTGROUPDESC}" ]; then
    echo "Insert hostgroup description"
    exit 1;
  fi

  # curl -i -d "hostname=lolcat&address=127.0.0.1&fqdn=lolcat.domain.tld&hostgroup=lolcat&hostgroupdesc=my%20sweet&snmpcommunity=snmpcom&operatingsystem=Debian" http://localhost:9393/nagiosql/c/host

  # change spaces into %20
  HOSTGROUPDESC_CLEAN="$(echo ${HOSTGROUPDESC} | sed 's/ /%20/g')"

  YASI_ADDHOST_PAYLOAD="hostname=${HOSTNAME}&address=${ADDRESS}&fqdn=${FQDN}&hostgroup=${HOSTGROUP}&hostgroupdesc=${HOSTGROUPDESC_CLEAN}&snmpcommunity=${SNMP_COMMUNITY}&operatingsystem=${OPERATINGSYSTEM}"

  echo ${DATE} >> ${LOGFILE}
  ${CURL_BIN} ${CURL_OPT} "${YASI_ADDHOST_PAYLOAD}" http://${YASI_HOST}:${YASI_PORT}/${YASI_ADDHOST_URI} >> ${LOGFILE}

}

case "${ACTION}" in
  "addhost" ) addhost ;;
  "help" | "" | * ) help exit 0 ;;
esac
