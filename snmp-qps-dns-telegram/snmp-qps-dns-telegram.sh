#!/bin/bash

#
# @File snmp-dns-qps-telegram.sh
# @Author mheidir
# @Created 15 May, 2017
# @Modified 15 May, 2017
# @Version 0.1
#
# @Description This is a limited release. For monitoring of BlueCat DDS DNS QPS and triggering a
#              telegram message to a bot (bcnmheidir_bot).
#
# @Requires curl, snmp
#
# NO WARRANTY
# THE PROGRAM IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS
# PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
# ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU. SHOULD THE PROGRAM
# PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR OR CORRECTION.
#
# IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW THE AUTHOR WILL BE LIABLE TO YOU FOR DAMAGES,
# INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR
# INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED
# INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE
# WITH ANY OTHER PROGRAMS), EVEN IF THE AUTHOR HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
#
#

# EDIT ME! - IP Address of BlueCat DDS
declare -a DdsServers=('10.0.1.252' '10.0.1.253')
qpsInterval=60        # Set according to CRON job frequency
qpsTriggerLimit=10    # Set a value that will trigger an alert if hit

# EDIT ME! - Directory for storing of QPS values. Default = same directory as script
dirStore='/home/bluecat/BAM_Backup/Bash/';

# EDIT ME! - Based on your telegram bot settings
CHATID="XXXXXXXXXXXX"
KEY="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

##### DO NOT EDIT DEFAULT TELEGRAM SETTIGNS #####
TIME="10"                                          # DO NOT EDIT
URL="https://api.telegram.org/bot$KEY/sendMessage" # DO NOT EDIT

################## DO NOT EDIT BEYOND THIS LINE ################
function getTotalCount () {
  ddsServer="$1"

  # BlueCat DDS - SNMP OIDs
  bcnDnsStatSrvQrySuccessOid='.1.3.6.1.4.1.13315.3.1.2.2.2.1.1.0'
  bcnDnsStatSrvQryFailureOid='.1.3.6.1.4.1.13315.3.1.2.2.2.1.6.0'

  bcnDnsStatSrvQrySuccess=( $(snmpget -v2c -c bcnCommunityV2C $ddsServer $bcnDnsStatSrvQrySuccessOid | sed 's/.* \(.*\)/\1/') )
  bcnDnsStatSrvQryFailure=( $(snmpget -v2c -c bcnCommunityV2C $ddsServer $bcnDnsStatSrvQryFailureOid | sed 's/.* \(.*\)/\1/') )

  local totalCnt=$((totalCnt = $bcnDnsStatSrvQrySuccess + $bcnDnsStatSrvQryFailure))
  echo "$totalCnt"
}

############ START OF SCRIPT ############
for ddsServer in "${DdsServers[@]}"; do

  fileName="$dirStore${ddsServer}_val.txt"
  #echo "$fileName"

  if [ -e "$fileName" ]; then          # Checks if file exists
    while IFS=' ' read -r -a line; do  # Read file and store as array
      storCnt="${line[0]}"             # File should only contain 1 value
    done < $fileName

    totalCnt=$(getTotalCount "$ddsServer")          # Get current query count
    echo "$totalCnt" > $fileName       # Save current value to file

    : $((diffCnt = $totalCnt - $storCnt)) # Calculate the difference

    : $((totalQps = $diffCnt / qpsInterval)) # Calculate QPS by Interval

    if [ $totalQps -gt $qpsTriggerLimit ]; then
      TEXT="[WARNING] Server: $ddsServer | Current QPS: $totalQps | Trigger QPS: $qpsTriggerLimit | Interval: $qpsInterval"      # Display calculated QPS
      curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT" $URL >/dev/null
      echo "$TEXT"
    else
      TEXT="[INFO] Server: $ddsServer | Current QPS: $totalQps | Trigger QPS: $qpsTriggerLimit | Interval: $qpsInterval"      # Display calculated QPS
      echo "$TEXT"                     # To display as information in syslog
    fi

  else
    totalCnt=$(getTotalCount "$ddsServer")          # Get current query count

    echo "$totalCnt" > $fileName       # Save current value to file

    TEXT="No QPS value, this is the first run | Server: $ddsServer | Trigger QPS: $qpsTriggerLimit | Interval: $qpsInterval"  # Tell user this is first run
    curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT" $URL >/dev/null
    echo "$TEXT"
  fi

done

exit 0
