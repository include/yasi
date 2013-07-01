#! /bin/bash
# cacti-cli.sh Manage Cacti
# Version - 0.3
# Date - 17/11/2011
# Francisco Cabrita - <francisco.cabrita@gmail.com>

DATE="$(date "+%Y%m%d%H")"

PHP_PATH="/servers/apache/php/bin"
PHP_CMD="php"
PHP_OPT="-q"
CACTI_CLI_PATH="/servers/apache/htdocs/cacti/cli"
ADD_DEVICE_CMD="add_device.php"
ADD_GRAPHS_CMD="add_graphs.php"
ADD_TREE_CMD="add_tree.php"

TMP_FILE="/tmp/cacti-cli-${DATE}.txt"
if [ -f "${TMP_FILE}" ]; then
  rm -f /tmp/cacti-cli-*
fi

ARGS=6
E_BADARGS=85

ACTION=$1
ARG1=$1
ARG2=$2
ARG3=$3
ARG4=$4
ARG5=$5
ARG6=$6

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

function help {
  echo ""
  echo "Usage:"
  echo "  cacti-cli.sh help"
  echo "  cacti-cli.sh adddevice hostname ip template_id=10 community hostgroup"
  echo "  cacti-cli.sh listhosttemplates"
  echo ""
}

function adddevice {

  GREAT_CMD="${PHP_PATH}/${PHP_CMD} ${PHP_OPT} ${CACTI_CLI_PATH}"

  HOSTNAME=$ARG2
  IP=$ARG3
  DEVICE_TEMPLATE=$ARG4
  SNMP_COMMUNITY=$ARG5
  HOSTGROUP=$ARG6

  if [ -z ${HOSTNAME} ]; then
    echo "Insert Hostname please!"
    exit 1;
  elif [ -z ${IP} ]; then
    echo "Insert IP Address please!"
    exit 1;
  elif [ -z ${DEVICE_TEMPLATE} ]; then
    echo "Insert Template id please!"
    exit 1;
  elif [ -z ${SNMP_COMMUNITY} ]; then
    echo "Insert snmp community please"
    exit 1;
  elif [ -z ${HOSTGROUP} ]; then
    echo "Insert hostgroup please!"
    exit 1;
  fi


  echo "Step 1 - Add device"
  echo "-------------------"

  # php -q add_device.php --description="Device Add Test" --ip="router.mydomain.com" --template=10 --community="public"

  HOST_NAME="$(${GREAT_CMD}/${ADD_GRAPHS_CMD} --list-hosts | grep $HOSTNAME | awk -F' ' '{print $4}')"

  # Verifies if hostname already exists

  if [ "${HOST_NAME}" = "${HOSTNAME}" ]; then
    echo "ERROR! Host ${HOSTNAME} already exists!"
    exit 1;
  fi


  # Add host

  ADD_DEVICE_PARAMS="--description="${HOSTNAME}" --ip="${IP}" --template=${DEVICE_TEMPLATE} --community="${SNMP_COMMUNITY}""

  ${GREAT_CMD}/${ADD_DEVICE_CMD} ${ADD_DEVICE_PARAMS}


  # Verifies if host has an host_id

  HOST_ID="$(${GREAT_CMD}/${ADD_GRAPHS_CMD} --list-hosts | grep $HOSTNAME | awk -F' ' '{print $1}')"

  if [ -z "${HOST_ID}" ]; then
    echo "ERROR! Host id: ${HOST_ID} not found for host: ${HOSTMAME}"
    exit 1;
  else
    echo "Step 2 - Add graph templates"
    echo "----------------------------"
    echo "CG Graphs"
    ${GREAT_CMD}/${ADD_GRAPHS_CMD} --graph-type=cg --graph-template-id=4 --host-id=${HOST_ID} >> ${TMP_FILE}
    ${GREAT_CMD}/${ADD_GRAPHS_CMD} --graph-type=cg --graph-template-id=7 --host-id=${HOST_ID} >> ${TMP_FILE}
    ${GREAT_CMD}/${ADD_GRAPHS_CMD} --graph-type=cg --graph-template-id=11 --host-id=${HOST_ID} >> ${TMP_FILE}
    ${GREAT_CMD}/${ADD_GRAPHS_CMD} --graph-type=cg --graph-template-id=14 --host-id=${HOST_ID} >> ${TMP_FILE}
    ${GREAT_CMD}/${ADD_GRAPHS_CMD} --graph-type=cg --graph-template-id=77 --host-id=${HOST_ID} >> ${TMP_FILE}

    echo "DS Graphs"
    # graph-template-id=2   => Interfacea traffic
    # snmp-query-id=1       => SNMP Interface Stats
    # snmp-query-type-id=14 => In/Out Bits (64-bit Counters)
    ${GREAT_CMD}/${ADD_GRAPHS_CMD} --host-id=${HOST_ID} --graph-type=ds --graph-template-id=2 --snmp-query-id=1 --snmp-query-type-id=14 --snmp-field=ifOperStatus --snmp-value=Up >> ${TMP_FILE}

    cat ${TMP_FILE} | awk -F' ' '{print $5}' | sed -e 's,(,,' -e 's,),,' > ${TMP_FILE}.swp
    mv ${TMP_FILE}.swp ${TMP_FILE}
  fi


  echo "Step 3 - Add tree"
  echo "-----------------"

  TREE_ID="$(${GREAT_CMD}/${ADD_TREE_CMD} --list-trees | grep ${HOSTGROUP} | awk -F' ' '{print $1}')"

  if [ -z "${TREE_ID}" ]; then
    TREE_ID="$(${GREAT_CMD}/${ADD_TREE_CMD} --type=tree --name="${HOSTGROUP}" --sort-method=manual | awk -F' ' '{print $NF}' | sed -e 's,(,,' -e 's,),,')"
  fi


  echo "Step 4 - Add host node to tree"
  echo "------------------------------"

  OUT="$(${GREAT_CMD}/${ADD_TREE_CMD} --type=node  --node-type=host --tree-id=${TREE_ID} --host-id=${HOST_ID})"

  echo "${OUT}"

  echo "Step 5 - Add graph node to tree"
  echo "-------------------------------"

  N=0
  cat ${TMP_FILE} | while read LINE ; do
    GRAPH_ID=${LINE}
    N=$((N+1))
    ${GREAT_CMD}/${ADD_TREE_CMD} --type=node  --node-type=graph --tree-id=${TREE_ID} --graph-id=${GRAPH_ID}
  done

  exit 0;
}


function listhosttemplates {

  ${PHP_PATH}/${PHP_CMD} ${PHP_OPT} ${CACTI_CLI_PATH}/${ADD_DEVICE_CMD} --list-host-templates

}


case "${ACTION}" in
  "adddevice" ) adddevice ;;
  "listhosttemplates" ) listhosttemplates ;;
  "help" | "" | * ) help exit 0; ;;
esac

exit 0;
