#!/bin/bash
#
#

echo "waiting for enrolment..."
while [ -f "/Library/Application Support/JAMF/FirstRun/Enroll/enroll.sh" ]
do
	sleep 3
done

echo "waiting for jss.."
until jamf checkJSSConnection
do
	sleep 3
done

echo "firing deploysetup trigger.."
jamf policy -trigger deploysetup

rm /Library/LaunchDaemons/com.github.patchoo-deploysetup.plist
rm /Library/LaunchAgents/com.github.patchoo-deploysetuploginlock.plist
rm "$0"

# unlock loginwindow
killall jamfHelper

reboot

exit 0