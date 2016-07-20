#!/bin/bash
#
#

# Where's the jamf binary stored? This is for SIP compatibility.
jamf_binary=`/usr/bin/which jamf`

 if [[ "$jamf_binary" == "" ]] && [[ -e "/usr/sbin/jamf" ]] && [[ ! -e "/usr/local/bin/jamf" ]]; then
    jamf_binary="/usr/sbin/jamf"
 elif [[ "$jamf_binary" == "" ]] && [[ ! -e "/usr/sbin/jamf" ]] && [[ -e "/usr/local/bin/jamf" ]]; then
    jamf_binary="/usr/local/bin/jamf"
 elif [[ "$jamf_binary" == "" ]] && [[ -e "/usr/sbin/jamf" ]] && [[ -e "/usr/local/bin/jamf" ]]; then
    jamf_binary="/usr/local/bin/jamf"
 fi

echo "waiting for enrolment..."
while [ -f "/Library/Application Support/JAMF/FirstRun/Enroll/enroll.sh" ]
do
	sleep 3
done

echo "waiting for jss.."
until $jamf_binary checkJSSConnection
do
	sleep 3
done

echo "firing deploysetup trigger.."
$jamf_binary policy -trigger deploysetup

rm /Library/LaunchDaemons/com.github.patchoo-deploysetup.plist
rm /Library/LaunchAgents/com.github.patchoo-deploysetuploginlock.plist
rm -rf "$0"

# unlock loginwindow
killall jamfHelper

reboot

exit 0