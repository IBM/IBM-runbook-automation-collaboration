#!/bin/bash
################################################################################
# RBASTAR
# A status reporter for IBM Runbook Automation. This tool delivers
# an overview about run-time information of a specific RBA PD installation.
# Requires: bash, curl
#
# Version: 0.7
# Date: AUG 2018
# Author: IBM
#
# © Copyright IBM Corporation 2018
# LICENSE: Apache License 2.0, https://opensource.org/licenses/Apache-2.0
################################################################################

# ------------------------------------------------------------------------------
# --------------------- BEGIN Configuration Section ----------------------------

# Specify RBA server of your RBA instance to
# use for report generation. In the case of RBA PD
# do not forget the port number, which is typically 3005
# - For RBA in Cloud typically: RBAServer=rba.mybluemix.net
# - For RBA Private Deployment use: RBAServer=<RBA Server Name>:3005
RBAServer=RBA_Server_Name:RBA_PORT

# Specify API Key to access server
RBAUser=API_key_name
RBAPass=API_key_password

# Configure the time period of the report
# choose YYYY-MM-DD as format.
# 'from' will start at the time 00:00:00.000
# 'to'   will end   at the time 23:59:59.999
from="2017-12-01"
to="2018-07-24"

# Configure which status blocks you want to
# get created: true | false
fCreateServiceStatus=true
fCreateRBStat=true
fCreateInstStat=true
fCreateTriggerStat=true

# --------------------- END Configuration Section ------------------------------
# --              !!! DO NOT CHANGE BELOW THIS LINE !!!                      ---
# ------------------------------------------------------------------------------

now=$(date)
version="0.7"

function jsonValue() {
KEY=$1
num=$2
awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'$KEY'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${num}p
}

echo "============================="
echo "RBASTAR - RBA Status Reporter"
echo "Version: " $version
echo "============================="

if [[ ${RBAServer:0:3} == "RBA" ]] || [[ ${RBAUser:0:3} == 'API' ]] || [[ ${RBAPass:0:3} == 'API' ]]
then
  echo
  echo "*** OPEN and EDIT this script to configure. ***"
  exit 1
fi

echo

echo
echo "Report created :" $now
echo "       period  :" $from " - " $to
echo "RBA Server     :" $RBAServer
echo
echo "Create Service Status          :" $fCreateServiceStatus
echo "Create Runbook Status          :" $fCreateRBStat
echo "Create Instances Status        :" $fCreateInstStat
echo "Create Trigger Status          :" $fCreateTriggerStat
echo

# First check if specified server is reachable via "curl"
curl -sSf -k -u $RBAUser:$RBAPass 'https://'$RBAServer'' > /dev/null 2>&1
fIsRBAServerReachable=$?
if [ $fIsRBAServerReachable -gt 0 ]
then
  echo "Unable to reach RBA with specified key on: " $RBAServer
  echo
  echo "Exiting."
  exit 1
fi

#Now fo a from/to precision - include from/to days
from="${from}T00%3A00%3A00.000Z"
to="${to}T23%3A59%3A59.999Z"

# Do the API calls to get the data
echo "Getting Data now..."

if [ "$fCreateServiceStatus" = true ] ; then
  echo $(date +%T) "Getting State of RBA Services"
  JS_RBA_Services=$(curl -s -k -u $RBAUser:$RBAPass https://$RBAServer/api/v1/rba/status)

  Status_RBS=$(echo $JS_RBA_Services | jsonValue rbs 1)
  Status_AS=$(echo $JS_RBA_Services | jsonValue as 1)
  Status_TS=$(echo $JS_RBA_Services | jsonValue ts 1)
  Status_DB=$(echo $JS_RBA_Services | jsonValue db 1)

  if [ $Status_RBS -eq 0 ]
  then
    Status_RBS="Okay"
  fi

  if [ $Status_AS -eq 0 ]
  then
    Status_AS="Okay"
  fi

  if [ $Status_TS -eq 0 ]
  then
    Status_TS="Okay"
  fi

  if [ $Status_DB -eq 0 ]
  then
    Status_DB="Okay"
  fi

  # Check Script Connection
  Status_Script_Connection=$(echo $JS_RBA_Services | jsonValue SCRIPT 1)
  if [ $Status_Script_Connection -eq 0 ]
  then
    Status_Script_Connection="Okay"
  else
    if [ $Status_Script_Connection -eq 2 ]
    then
      Status_Script_Connection="Not configured"
    fi
  fi

  # Check Trigger Connection
  Status_Trigger_Connection=$(echo $JS_RBA_Services | jsonValue IMPACT 1)

  if [ "$Status_Trigger_Connection" = "" ]
  then
    Status_Trigger_Connection=$(echo $JS_RBA_Services | jsonValue TRIGGER 1)
  fi

  if [ "$Status_Trigger_Connection" != "" ]
  then
    if [ $Status_Trigger_Connection -eq 0 ]
    then
      Status_Trigger_Connection="Okay"
    else
      if [ $Status_Trigger_Connection -eq 2 ]
      then
        Status_Trigger_Connection="Not configured"
      fi
    fi
  else
    Status_Trigger_Connection="Not available"
  fi

  # Check Bigfix Connection
  Status_Bigfix_Connection=$(echo $JS_RBA_Services | jsonValue BIGFIX 1)

  if [ "$Status_Bigfix_Connection" != "" ]
  then
    if [ $Status_Bigfix_Connection -eq 0 ]
    then
      Status_Bigfix_Connection="Okay"
    else
      if [ $Status_Bigfix_Connection -eq 2 ]
      then
        Status_Bigfix_Connection="Not configured"
      fi
    fi
  else
    Status_Bigfix_Connection="Not available"
  fi
fi


echo $(date +%T) "Getting RBA Statistics"
JS_RBA_Stats=$(curl -s -k -u $RBAUser:$RBAPass 'https://'$RBAServer'/api/v1/rba/statistics/runbookinstances?startTime='$from'&endTime='$to'')
Num_RunbooksExecuted=$(echo $JS_RBA_Stats | jsonValue productionExecutions 1);

if [ "$fCreateRBStat" = true ] ; then
  echo $(date +%T) "Getting All DRAFT + APPROVED + ARCHIVED Runbooks"
  JS_RunbooksAll=$(curl -s -k -u $RBAUser:$RBAPass 'https://'$RBAServer'/api/v1/rba/runbooks?version=all&fields=name,_runbookId')
  Num_RunbooksAll=$(echo $JS_RunbooksAll | grep -o "_runbookId" | wc -l)

  echo $(date +%T) "Getting Latest Runbooks"
  JS_RunbookLatest=$(curl -s -k -u $RBAUser:$RBAPass 'https://'$RBAServer'/api/v1/rba/runbooks?version=latest&fields=name,_runbookId')
  Num_RunbookLatest=$(echo $JS_RunbookLatest | grep -o "_runbookId" | wc -l)

  echo $(date +%T) "Getting All APPROVED Runbooks "
  JS_RunbooksApproved=$(curl -s -k -u $RBAUser:$RBAPass 'https://'$RBAServer'/api/v1/rba/runbooks?version=approved&fields=name,_runbookId')
  Num_RunbooksApproved=$(echo $JS_RunbooksApproved | grep -o "_runbookId" | wc -l)
fi


if [ "$fCreateInstStat" = true ] ; then
  echo $(date +%T) "Getting All Runbook Instances "
  JS_InstancesAll=$(curl -s -k -u $RBAUser:$RBAPass 'https://'$RBAServer'/api/v1/rba/runbookinstances?from='$from'&to='$to'&fields=_runbookName,_id,status')
  Num_InstancesAll=$(echo $JS_InstancesAll | grep -o "_id" | wc -l)

  echo $(date +%T) "Getting All Manual Runbook Instances "
  JS_ManualInstancesAll=$(curl -s -k -u $RBAUser:$RBAPass 'https://'$RBAServer'/api/v1/rba/runbookinstances?from='$from'&to='$to'&type=manual&fields=_runbookName,_id')
  Num_ManualInstancesAll=$(echo $JS_ManualInstancesAll | grep -o "_id" | wc -l)

  echo $(date +%T) "Getting All Automated Runbook Instances "
  JS_AutomatedInstancesAll=$(curl -s -k -u $RBAUser:$RBAPass 'https://'$RBAServer'/api/v1/rba/runbookinstances?from='$from'&to='$to'&type=automated&fields=_runbookName,_id')
  Num_AutomatedInstancesAll=$(echo $JS_AutomatedInstancesAll | grep -o "_id" | wc -l)

  echo $(date +%T) "Getting All Complete Runbook Instances "
  JS_InstancesComplete=$(curl -s -k -u $RBAUser:$RBAPass 'https://'$RBAServer'/api/v1/rba/runbookinstances?from='$from'&to='$to'&status=complete&fields=_runbookName,_id')
  Num_InstancesComplete=$(echo $JS_InstancesComplete | grep -o "_id" | wc -l)

  echo $(date +%T) "Getting All InProgress Runbook Instances "
  JS_InstancesInProgress=$(curl -s -k -u $RBAUser:$RBAPass 'https://'$RBAServer'/api/v1/rba/runbookinstances?from='$from'&to='$to'&status=in%20progress&fields=_runbookName,_id')
  Num_InstancesInProgress=$(echo $JS_InstancesInProgress | grep -o "_id" | wc -l)

  echo $(date +%T) "Getting All Success Runbook Instances "
  JS_InstancesSuccess=$(curl -s -k -u $RBAUser:$RBAPass 'https://'$RBAServer'/api/v1/rba/runbookinstances?from='$from'&to='$to'&status=success&fields=_runbookName,_id')
  Num_InstancesSuccess=$(echo $JS_InstancesSuccess | grep -o "_id" | wc -l)

  echo $(date +%T) "Getting All failed Runbook Instances "
  JS_InstancesFailed=$(curl -s -k -u $RBAUser:$RBAPass 'https://'$RBAServer'/api/v1/rba/runbookinstances?from='$from'&to='$to'&status=failure&fields=_runbookName,_id')
  Num_InstancesFailed=$(echo $JS_InstancesFailed | grep -o "_id" | wc -l)

  echo $(date +%T) "Getting All cancelled Runbook Instances "
  JS_InstancesCancelled=$(curl -s -k -u $RBAUser:$RBAPass 'https://'$RBAServer'/api/v1/rba/runbookinstances?from='$from'&to='$to'&status=cancelled&fields=_runbookName,_id')
  Num_InstancesCancelled=$(echo $JS_InstancesCancelled | grep -o "_id" | wc -l)
fi

if [ "$fCreateTriggerStat" = true ] ; then
  echo $(date +%T) "Getting Defined Triggers "
  JS_TriggersAll=$(curl -s -k -u $RBAUser:$RBAPass 'https://'$RBAServer'/api-gateway/ts/api/ts/trigger/runbookTriggers/event')
  Num_AllRBTriggers=$(echo $JS_TriggersAll | grep -o "TriggerID" | wc -l)
fi

echo "... Got all Data."

echo
if [ "$fCreateServiceStatus" = true ] ; then
  echo "RBA Services"
  echo "-----------------------------"
  echo "Automation service     : " $Status_AS
  echo "Runbook service        : " $Status_RBS
  echo "Trigger service        : " $Status_TS
  echo "DB service             : " $Status_DB
  echo
  echo "Connections"
  echo "-----------------------------"
  echo "Trigger (Impact)       : " $Status_Trigger_Connection
  echo "Script                 : " $Status_Script_Connection
  echo "Bigfix                 : " $Status_Bigfix_Connection
  echo
fi

if [ "$fCreateRBStat" = true ] ; then
  echo "Runbooks (RB)"
  echo "-----------------------------"
  echo "Unique RB              : " $Num_RunbookLatest
  echo "Different RB versions  : " $Num_RunbooksAll
  echo "Approved RB            : " $Num_RunbooksApproved
  echo
fi

echo "Runbook (RB) instances "
echo "-----------------------------"
echo "All approved RB executed : " $Num_RunbooksExecuted
echo "All RB instances         : " $Num_InstancesAll
echo

if [ "$fCreateInstStat" = true ] ; then
  echo "Run runbooks"
  echo "   Status inProgress   : " $Num_InstancesInProgress
  echo "   Status complete     : " $Num_InstancesComplete
  echo "     Status success    : " $Num_InstancesSuccess
  echo "     Status failed     : " $Num_InstancesFailed
  echo "     Status cancelled  : " $Num_InstancesCancelled

  echo
  echo "Manual run runbooks    : " $Num_ManualInstancesAll
  echo "   ******************* TOP10 runbooks run manually *********************** "
  echo $JS_ManualInstancesAll | tr ',' '[\n*]' | grep -v "^\s*$" | sort | uniq -c | sort -bnr | head -n10
  echo "   *********************************************************************** "
  echo
  echo "Automated run runbooks : " $Num_AutomatedInstancesAll
  echo "   ******************* TOP10 runbooks run automated*********************** "
  echo $JS_AutomatedInstancesAll | tr ',' '[\n*]' | grep -v "^\s*$" | sort | uniq -c | sort -bnr | head -n10
  echo "   *********************************************************************** "
  echo
fi

if [ "$fCreateTriggerStat" = true ] ; then
  echo "Triggers for runbooks"
  echo "-----------------------------"
  echo "Total number of trigger: " $Num_AllRBTriggers

  echo "   ******************* Trigger & Mappings ******************************** "
  for (( i=1; i<=$Num_AllRBTriggers; i++ ))
  do
    Name_Trigger=$(echo $JS_TriggersAll | jsonValue name $i)
    ID_MappedRB=$(echo $JS_TriggersAll | jsonValue mappedRunbookId $i)

    # Get the name of the linked runbook
    JS_MappedRunbookName=$(curl -s -k -u $RBAUser:$RBAPass 'https://'$RBAServer'/api/v1/rba/runbooks/'$ID_MappedRB'?fields=name')
    Name_RunbookMappedByTrigger=$(echo $JS_MappedRunbookName | jsonValue name 1)

    # Get the instances of the mapped runbooks
    JS_MappedRunbookInstances=$(curl -s -k -u $RBAUser:$RBAPass 'https://'$RBAServer'/api/v1/rba/runbookinstances?from='$from'&to='$to'&runbook='$ID_MappedRB'&type=automated&fields=_id,_createdAt,status')
    #echo $JS_MappedRunbookInstances

    STR_InstanceStats="NOT calculated"
    if [[ $JS_MappedRunbookInstances = "[]" ]]
    then
      STR_InstanceStats="Trigger has not launched runbook in specified time period."
    else
      Num_TriggerTotalCalledRBInstances=$(echo $JS_MappedRunbookInstances | grep -o "_id" | wc -l)
      Num_TriggerCalledRBInstancesSuccess=$(echo $JS_MappedRunbookInstances | grep -o "success" | wc -l)
      Num_TriggerCalledRBInstancesErrors=$(echo $JS_MappedRunbookInstances | grep -o "have errors" | wc -l)
      STR_InstanceStats="Total: $Num_TriggerTotalCalledRBInstances Success: $Num_TriggerCalledRBInstancesSuccess Errors: $Num_TriggerCalledRBInstancesErrors"
    fi

    echo "  " $Name_Trigger
    echo "     launches -> " $Name_RunbookMappedByTrigger
    echo "     statistics: " $STR_InstanceStats
    echo

  done
  echo "   *********************************************************************** "
fi

echo "Exiting."
exit 0
