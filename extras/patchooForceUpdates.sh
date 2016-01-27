#!/bin/bash -xv
#
# this script initiates a bootstrap mode / force update loop.
# fire it on the startup trigger
# scope to a group that has patchooDefercount +10 (or your threshold)
#
# next time mac is restarted, it will lock loginwindow and reboot to bootstrap / loop all updates
#
message="This Mac has pending software updates that must be installed now!

Restarting..."

"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" -windowType fs -description "${message}" -icon /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns &
jamf policy -trigger bootstrapsetup
reboot
exit 0
