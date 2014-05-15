#!/bin/bash
#
# this script will setup junki bootstrap, it needs to wait for the the mac to be enrolled and the first run scripts to finish

#if [ "$1" != "--spawned" ]
#then
#	cp "$0" "/tmp/junkbootstrapsetup.sh"
#	# spawn the script in the background
#	/tmp/junkbootstrapsetup.sh --spawned &
#	exit 0	
#fi

# wait for the enrollment to complete
#while [ -d '/Library/Application Support/JAMF/FirstRun/Enroll' ]
#do
#	echo "waiting..."
#	sleep 2
#done

# wait for the postinstall to complete
#while [ -d '/Library/Application Support/JAMF/FirstRun/PostInstall' ]
#do
#	echo "waiting..."
#	sleep 2
#done

jamf policy -trigger bootstrapsetup
reboot &

exit 0