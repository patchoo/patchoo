#!/bin/bash
#
# patchoo!
# ========
# Casper patching done right!
#
# https://github.com/patchoo/patchoo
#
# patchoo somewhat emulates munki workflows and user experience for JAMF's Casper.
#

###################################
#
# start configurable settings
#
###################################

name="patchoo"
version="0.9960"

# read only api user please!
apiuser="apirw"
apipass="apirw"

datafolder="/Library/Application Support/patchoo"
pkgdatafolder="$datafolder/pkgdata"
prefs="$datafolder/com.github.patchoo"
cdialog="/Applications/Utilities/cocoaDialog.app"	#please specify the appbundle rather than the actual binary
tnotify="/Applications/Utilities/terminal-notifier.app" #please specify the appbundle rather than the actual binary
jamfhelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

# Where's the jamf binary stored? This is for SIP compatibility.
jb=`/usr/bin/which jamf`

 if [[ "$jb" == "" ]] && [[ -e "/usr/sbin/jamf" ]] && [[ ! -e "/usr/local/bin/jamf" ]]; then
    jb="/usr/sbin/jamf"
 elif [[ "$jamf_binary" == "" ]] && [[ ! -e "/usr/sbin/jamf" ]] && [[ -e "/usr/local/bin/jamf" ]]; then
    jb="/usr/local/bin/jamf"
 elif [[ "$jamf_binary" == "" ]] && [[ -e "/usr/sbin/jamf" ]] && [[ -e "/usr/local/bin/jamf" ]]; then
    jb="/usr/local/bin/jamf"
 fi

# if you are using a self signed cert for you jss, tell curl to allow it.
selfsignedjsscert=true

# users can defer x update prompts
defermode=true
defaultdeferthresold="10"

# REALLY forces a logout when defers run out
nastymode=true

# users running blocking apps will have x number of prompts delayed, ie will not run on prompt/remindto install until threshold is reached
blockingappmode=true
defaultblockappthreshold="2" # if missed at lunch, then 2x2 hours later... should prompt in afternoon?

# if these apps are in the foreground notifications will not be displayed, presentation apps ? (check with names- sleep 5; osascript -e 'tell application "System Events"' -e 'set frontApp to name of first application process whose frontmost is true' -e 'end tell')
blockingapps=( "Microsoft PowerPoint" "Keynote" "GoToMeeting" )

# this order will correspond to the updatetriggers and asurelease catalogs
# eg. 	jssgroup[2]="patchooBeta"
#  		updatetrigger[2]="update-beta"
#		asureleasecatalog[2]="beta"
#
# index 0 is the production group and is assumed unless the client is a member of any other groups

jssgroup[0]="----PRODUCTION----"
jssgroup[1]="patchooDev"
jssgroup[2]="patchooBeta"
	
# these triggers are run based on group membership, index 0 is run after extra group.
patchooswreleasemode=false
updatetrigger[0]="update"
updatetrigger[1]="update-dev"
updatetrigger[2]="update-beta"

# if using patchoo asu release mode these will be appended to computer's SoftwareUpdate server catalogs as per reposado forks -- if not using asu release mode the computer's SwUpdate server will remain untouched.
# eg. http://swupdate.your.domain:8088/content/catalogs/others/index-leopard.merged-1${asureleasecatalogs[i]}.sucatalog
patchooasureleasemode=false
asureleasecatalog[0]="prod"
asureleasecatalog[1]="dev"
asureleasecatalog[2]="beta"

#
# patchooDeploy settings
#
pdusebuildea="false" # isn't setting the ea on the computer record
pdusedepts="true"
pdusebuildings="true"

pdsetcomputername=true # prompt to set computername

# the name of your ext attribute to use as the patchooDeploy build identfier - a populated dropdown EA.
pdbuildea="patchoo Build"

# do you want to prompt the console user to set attributes post enrollment? (not possible post casper imaging)
pdpromptprovisioninfo=true

# this api user requires update/write access to computer records (somewhat risky putting in here - see docs) 
# leaving blank will prompt console user for a jss admin account during attribute set (as above)
pdapiadminname="apirw"
pdapiadminpass="apirw"

pddeployreceipt="/Library/Application Support/JAMF/Receipts/patchooDeploy" # this fake receipt internally, and to communicate back to the jss about different patchoo deploy states.

#########################################
#
# configure user prompts and feedback.
#
#########################################

msgtitlenewsoft="New Software Available"
msgnewsoftware="The following new software is available"
msginstalllater="(You can perform the installation later via Self Service)"
msgnewsoftforced="The following software must be installed now!"
msgbootstrap="Mac is provisioning. Do not interrupt or power off."
msgbootstapdeployholdingpattern="Awaiting provisioning information. Your admin has been notified."
msgpatchoodeploywelcome="Welcome to patchoo deploy.
We are gathering provisioning information"
msgshortfwwarn="
IMPORTANT: A firmware update will be installed.
Ensure you connect AC power before starting the update process."
msgshortoswarn="
IMPORTANT: A major OS X upgrade will be performed.
Ensure you connect AC power before starting the update process.
It could take up to 90 minutes to complete."
msgfirmwarewarning="
Firmware updates will be installed after your computer restarts.
Please ensure you are connected to AC Power! Do NOT touch any keys or the power button! A long tone will sound and your screen may be blank for up to 5 minutes.
IT IS VERY IMPORTANT YOU DO NOT INTERRUPT THIS PROCESS AS IT MAY LEAVE YOUR MAC INOPERABLE"
msgosupgradewarning="
Your computer is peforming a major OS X upgrade.
Please ensure you are connected to AC Power! Your computer will restart and the OS upgrade process will continue. It will take up to 90 minutes to complete.
IT IS VERY IMPORTANT YOU DO NOT INTERRUPT THIS PROCESS AS IT MAY LEAVE YOUR MAC INOPERABLE"

iconsize="72"
dialogtimeout="210"

# This is used for banding purposes. Replace with your own corporate icns file.
lockscreenlogo="/System/Library/CoreServices/Installer.app/Contents/Resources/Installer.icns"

# log to the jamf log.
logto="/var/log/"
log="jamf.log"

##################################
##################################
##
##  end of configurable settings
##
##################################
##################################

osxversion=$(sw_vers -productVersion | cut -f-2 -d.) # we don't need patch version
udid=$( ioreg -rd1 -c IOPlatformExpertDevice | awk '/IOPlatformUUID/ { split($0, line, "\""); printf("%s\n", line[4]); }' )

OLDIFS="$IFS"
IFS=$'\n'

# command line paramaters
mode="$4"
prereqreceipt="$5"
prereqpolicy="$(echo "$6" | sed -e 's/ /\+/g')" # change out " " for +
option="$7"
spawned="$1" # used internally

if $selfsignedjsscert
then
	curlopts="-k"
else
	curlopts=""
fi

cdialogbin="${cdialog}/Contents/MacOS/cocoaDialog"
tnotifybin="${tnotify}/Contents/MacOS/terminal-notifier"
bootstrapagent="/Library/LaunchAgents/com.company.patchoo-bootstrap.plist"
jssgroupfile="$datafolder/$name-jssgroups.tmp"

# set and read preferences
computername=$(scutil --get ComputerName)
jssurl=$(defaults read /Library/Preferences/com.jamfsoftware.jamf "jss_url" 2> /dev/null)

daystamp=$(( $(date +%s) / 86400 )) # days since 1-1-70

# cocoaDialog issue fixed.

displayatlogout=true

# create the data folder if it doesn't exist
[ ! -d "$datafolder" ] && mkdir -p "$datafolder"
[ ! -d "$pkgdatafolder" ] && mkdir -p "$pkgdatafolder"
chmod 700 "$datafolder"

# if there is no receipt dir, best make one... derp.
[ ! -d "/Library/Application Support/JAMF/Receipts" ] && mkdir -p "/Library/Application Support/JAMF/Receipts"

# DEBUG STUFF
if [ -f "$datafolder/.patchoo-debug" ]
then
	set -vx	# DEBUG.
	debugpath="$datafolder/debuglogs"
	mkdir -p "$debugpath"
	debuglogfile="$debugpath/patchoo${mode}-$(date "+%F_%H-%M-%S").log"
	exec > "$debuglogfile" 2>&1
fi

# check and write installs avail

installsavail=$(defaults read "$prefs" InstallsAvail 2> /dev/null)
if [ "$?" != "0" ]
then
	defaults write "$prefs" InstallsAvail -string "No"
	installsavail="No"
fi

# set defaults for defer and blockingapp counts

# defer is the # of times a user can defer updates
deferthreshold=$(defaults read "$prefs" DeferThreshold 2> /dev/null)
if [ "$?" != "0" ]
then
	defaults write "$prefs" DeferThreshold -int $defaultdeferthresold
	deferthreshold=$defaultdeferthresold
fi
defercount=$(defaults read "$prefs" DeferCount 2> /dev/null)
if [ "$?" != "0" ]
then
	defaults write "$prefs" DeferCount -int 0
	defercount=0
fi

# blockingapp is the # of times a blocking app can block a prompt
blockappthreshold=$(defaults read "$prefs" BlockingAppThreshold 2> /dev/null)
if [ "$?" != "0" ]
then
	defaults write "$prefs" BlockingAppThreshold -int $defaultblockappthreshold
	blockappthreshold=$defaultblockappthreshold
fi
blockappcount=$(defaults read "$prefs" BlockingAppCount 2> /dev/null)
if [ "$?" != "0" ]
then
	defaults write "$prefs" BlockingAppCount -int 0
	blockappcount=0
fi


# if the bootstrap agent exists, set bootstrapmode
if [ -f "$bootstrapagent" ]
then
	bootstrapmode=true
else
	bootstrapmode=false
fi

# make tmp folder
patchootmp="$(mktemp -d -t patchoo)" 

#
# common functions 
#

secho()
{
	# superecho - writes to log and will display a dialog to gui with timeout
	message="$1"
	timeout="$2"
	title="$3"
	icon="$4"

	if [ "$timeout" != "" ]
	then
		echo "$name: USERNOTIFY: $title, $message"
		echo "$(date "+%a %b %d %H:%M:%S") $computername $name-$version $mode: USERNOTIFY: $title, $message" >> "$logto/$log"			

		if [ "$(checkConsoleStatus)" == "userloggedin" ]
		then
			[ "$title" == "" ] && title="Message"
			[ "$icon" == "" ] && icon="notice"
			"$tnotifybin" -title "$title" -message "$message"
			# "$cdialogbin" bubble --title "$title" --text "$message" --icon "$icon" --timeout "$timeout" &
		fi
	else
		echo "$name: $message"
		echo "$(date "+%a %b %d %H:%M:%S") $computername $name-$version $mode: $message" >> "$logto/$log"
	fi
}

displayDialog()
{
	text="$1"		# core message
	title="$2"		# menubar title
	title2="$3"		# bold title
	icon="$4"		# http://mstratman.github.io/cocoadialog/#documentation3.0/icons
	button1="$5"
	button2="$6"
	button3="$7"
	
	# show the dialog...
	"$cdialogbin" msgbox --title "$title" --icon-file "$icon" --text "$title2" --informative-text "$text" --timeout "$dialogtimeout" --button1 "$button1" --button2 "$button2" --button3 "$button3" --icon-height "$iconsize" --icon-width "$iconsize" --width "500" --string-output
}

makeMessage()
{
	message="$message
	$1"
}

checkConsoleStatus()
{
	userloggedin="$(who | grep console | awk '{print $1}')"
	consoleuser="$(python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')"
	screensaver="$(pgrep ScreenSaverEngine)"

	if [ "$screensaver" != "" ]
	then
		# screensaver is running
		echo "screensaver"
		return
	fi
	
	if [ "$userloggedin" == "" ]
	then
		# no users logged in (at loginwindow)
		echo "nologin"
		return
	fi
	
	if [ "$userloggedin" != "$consoleuser" ]
	then
		# a user is loggedin, but we are at loginwindow or we have multiple users logged in with switching (too hard for now)
		echo "loginwindow"
		return
	fi

	if $blockingappmode
	then
		# get foreground app
		fgapp=$(sudo -u "$userloggedin" osascript -e "tell application \"System Events\"" -e "return name of first application process whose frontmost is true" -e "end tell"  2> /dev/null) # avoid errors in log
		# check for blocking apps		
		for app in ${blockingapps[@]}
		do
			if [ "$app" == "$fgapp" ]
			then
				echo "BlockingApp: $app"
				return
			fi
		done
	fi

	# if we passed all checks, user is logged in and we are safe to prompt or display bubbles
	echo "userloggedin"
}

checkProcess()
{
	if [ "$(pgrep "$1")" != "" ]
	then
		return 0
	else
		return 1
	fi
}

spawnScript()
{
	# we use this so we can execute from self service.app and call a logout with out breaking policy execution.
	# the script copies, then spawns itself 
	if [ "$spawned" != "--spawned" ]
	then
		tmpscript="$datafolder/$name-$RANDOM.sh"
		cp "$0" "$tmpscript"
		# spawn the script in the background
		secho "spawned script $tmpscript"
		"$tmpscript" --spawned '' '' $mode &
		cleanUp
		exit 0	
	fi
}

#
# the mains brains.
#


cachePkg()
{
	# run after a pkg is cached in a policy
	#	- checks for prereqs and calls policies if receipts not found
	#	- gets pkg data from jss api and gives pkg friendly name in the gui
	#
	
	# find the latest addition to the Waiting Room
	pkgname=$(ls -t "/Library/Application Support/JAMF/Waiting Room/" | head -n 1 | grep -v .cache.xml)
	if [ ! -f "$pkgdatafolder/$pkgname.caspinfo" ] && [ "$pkgname" != "" ]
	then
		pkgext=${pkgname##*.} 	# handle zipped bundle pkgs
		[ "$pkgext" == "zip" ] && pkgnamelesszip=$(echo "$pkgname" | sed 's/\(.*\)\..*/\1/')
		# get pkgdata from the jss api
		curl $curlopts -H "Accept: application/xml" -s -u "$apiuser:$apipass" "${jssurl}JSSResource/packages/name/$pkgname" -X GET > "$pkgdatafolder/$pkgname.caspinfo.xml"
		# (error checking)
		pkgdescription=$(cat "$pkgdatafolder/$pkgname.caspinfo.xml" | xpath //package/info 2> /dev/null | sed 's/<info>//;s/<\/info>//')
		if [ "$pkgdescription" == "<info />" ] || [ "$pkgdescription" == "" ] # if it's no pkginfo in jss, set pkgdescription to pkgname (less ext)
		then
			if [ "$pkgext" == "zip" ]
			then
				pkgdescription=$(echo "$pkgname" | sed 's/\(.*\)\..*/\1/') 
			else
				pkgdescription=$(echo "$pkgnamelesszip" | sed 's/\(.*\)\..*/\1/')
			fi
		fi
		echo "$pkgdescription" > "$pkgdatafolder/$pkgname.caspinfo"

		# if it's flagged as an OS Upgrade (using createOSXInstallPkg), add osupgrade flag
		[ "$option" == "--osupgrade" ] && touch "$pkgdatafolder/.os-upgrade"
		secho "jamf has cached $pkgname"
		secho "$pkgdescription" 2 "Downloaded" "globe"
		# flag that we need a recon
		touch "$datafolder/.patchoo-recon-required"

		if [ "$prereqreceipt" != "" ]
		then
			# we need to check for a prereq casper receipt
			if [ ! -f "/Library/Application Support/JAMF/Receipts/$prereqreceipt" ]
			then
				# the receipt wasn't found
				# query the JSS for the prereqpolicy
				secho "$prereqreceipt is required and NOT found"
				secho "querying jss for policy $prereqpolicy to install $prereqreceipt"
				prereqpolicyid=$(curl $curlopts -H "Accept: application/xml" -s -u "$apiuser:$apipass" "${jssurl}JSSResource/policies/name/$prereqpolicy" -X GET | xpath //policy/general/id 2> /dev/null | sed -e 's/<id>//;s/<\/id>//')
				# (error checking)
				# let's run the preq policy via id
				# this is how we chain incremental updates
				$jb policy -id "$prereqpolicyid"
			fi
		fi
	else
		secho "i couldn't find a new pkg in the waiting room. :("
	fi

}

checkASU()
{
	if [ -f "$pkgdatafolder/.os-upgrade" ]
	then
		secho "os upgrade is cached, skipping apple software updates.."
		return
	fi
	
	if $patchooasureleasemode
	then
		getGroupMembership
		setASUCatalogURL
	fi

	swupdateout="$patchootmp/swupdateout-$RANDOM.tmp"
	secho "checking for apple software updates ..."
	softwareupdate -la > "$swupdateout"
	# check if there are any updates
	if [ "$(cat "$swupdateout" | grep "\*")" != "" ]
	then
		# let's parse the updates
		asupkgarray=( $(cat "$swupdateout" | grep "\*" | cut -c6- ) )
		asudescriptarray=( $(cat "$swupdateout" | grep -A2 "\*" | grep -v "\*" | cut  -f1 -d, | cut -c2- | sed 's/[()]//g' ) )
		
		# first clean up any packages that were installed from the appstore - thanks galenrichards
		find "$pkgdatafolder" -iname "*.asuinfo" | while read f
	    do
	    	basefile=$(basename "$f" ".asuinfo")
	        if [[ ! " ${asupkgarray[@]//.} " =~ " ${basefile//.} " ]]; then
	            secho "$basefile not available or already installed. Removing..."
	            rm $f
	        fi
	    done
	       
		i=0
		for asupkg in ${asupkgarray[@]} 
		do
			if [ ! -f "$pkgdatafolder/$asupkg.asuinfo" ] # it hasn't been downloaded
			then
				secho "softwareupdate is downloading $asupkg"
				softwareupdate -d "$asupkg"
				# (insert error checking)
				echo "${asudescriptarray[$i]}" > "$pkgdatafolder/$asupkg.asuinfo"
				secho "${asudescriptarray[$i]}" 2 "Downloaded" "globe"
				# flag that we need a recon
				touch "$datafolder/.patchoo-recon-required"
			else
				secho "$asupkg already downloaded."
			fi
			(( i ++ ))
		done 

		# check for restart required
		if [ "$(cat "$swupdateout" | grep "\[restart\]")" != "" ]
		then
			touch "$pkgdatafolder/.restart-required"
		fi
	else
		secho "no updates found."
	fi
	rm "$swupdateout"
}

setASUCatalogURL()
{
	# in patchooasureleasemode mode patchoo takes care of re-writing client catalog urls so you can have dev/beta/prod catalogs based on jss group membership
	# you set your catalogURL / swupdate server as you usually do in Casper, and it will re-write OS and branch specific URLs based on the local CatalogURL.
	# it assumes that you have turned off updates via other mechanisms 
	currentswupdurl=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate CatalogURL 2> /dev/null)
	
	if [ "$currentswupdurl" != "" ]
	then
		asuserver="$(echo "$currentswupdurl" | cut -f-3 -d/)"
		case $osxversion in	
			10.5)
				swupdateurl="$asuserver/content/catalogs/others/index-leopard.merged-1_${asureleasecatalog[$groupid]}.sucatalog"
				;;
			10.6)
				swupdateurl="$asuserver/content/catalogs/others/index-leopard-snowleopard.merged-1_${asureleasecatalog[$groupid]}.sucatalog"
				;;
			10.7)
				swupdateurl="$asuserver/content/catalogs/others/index-lion-snowleopard-leopard.merged-1_${asureleasecatalog[$groupid]}.sucatalog"
				;;
			10.8)
				swupdateurl="$asuserver/content/catalogs/others/index-mountainlion-lion-snowleopard-leopard.merged-1_${asureleasecatalog[$groupid]}.sucatalog"
				;;
			10.9)
				swupdateurl="$asuserver/content/catalogs/others/index-10.9-mountainlion-lion-snowleopard-leopard.merged-1_${asureleasecatalog[$groupid]}.sucatalog"
				;;
			10.10)
				swupdateurl="$asuserver/content/catalogs/others/index-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1_${asureleasecatalog[$groupid]}.sucatalog"
				;;
			10.11)
				swupdateurl="$asuserver/content/catalogs/others/index-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog_${asureleasecatalog[$groupid]}.sucatalog"
				;;
			10.12)
				swupdateurl="$asuserver/content/catalogs/others/index-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog_${asureleasecatalog[$groupid]}.sucatalog"
				;;
			*)
				secho "I can't do this OS X version.. sadface."
				return
				;;
		esac
		secho "setting asu CatalogURL to $swupdateurl"
		defaults write /Library/Preferences/com.apple.SoftwareUpdate CatalogURL "$swupdateurl"
	else
		secho "no asu server set, using apple's ..."
	fi
}

buildUpdateLists()
{
	# make software install list tmp files for processing later
	#
	# don't expand a nullglob (if there are no matching *.xxx)
	shopt -s nullglob
	# casper pkgs
	casppkginfo="$patchootmp/casppkginfo-$RANDOM.tmp"
	for infofile in "$pkgdatafolder/"*.caspinfo
	do
		# parse the priority from casper xml
		casppriority=$(cat "${infofile}.xml" | xpath //package/priority 2> /dev/null | sed 's/<priority>//;s/<\/priority>//')
		casppkg=$(basename "$infofile")		#get rid of path
		casppkg="${casppkg%\.*}"				#remove ext.
		casppkgdescrip=$(cat "$infofile")
		echo -e "${casppriority}\t${casppkg}\t${casppkgdescrip}" >> "$casppkginfo"
	done
	
	# if there is an OS Upgrade packge cached in the casper installs, skip the apple updates
	if [ -f "$pkgdatafolder/.os-upgrade" ]
	then
		secho "osupgrade is in casper, skipping apple software updates"
	else
		# asu pkgs
		asupkginfo="$patchootmp/asupkginfo-$RANDOM.tmp"
		for infofile in "$pkgdatafolder/"*.asuinfo
		do
			# check for SMC, EFI and Firmware updates, flag if so
			[ "$(echo "$infofile" | grep EFIUpdate)" != "" ] && touch "$pkgdatafolder/.fw-update"
			[ "$(echo "$infofile" | grep SMCUpdate)" != "" ] && touch "$pkgdatafolder/.fw-update"
			[ "$(echo "$infofile" | grep Firmware)" != "" ] && touch "$pkgdatafolder/.fw-update"			
			# set priorities for system and sec updates
			asupriority=1
			#  OSX supplemental for 10.8.5 broke the rules, not OSXUpd... this could catch other things too... hmm.
			[ "$(echo "$infofile" | grep OSX)" != "" ] && asupriority="98"
			# if it's a security or OSX update make it 99
			[ "$(echo "$infofile" | grep SecUpd)" != "" ] && asupriority="99"	
			[ "$(echo "$infofile" | grep OSXUpd)" != "" ] && asupriority="99"
			asupkg=$(basename "$infofile")	#get rid of path
			asupkg="${asupkg%\.*}"		#remove ext.
			asupkgdescrip=$(cat "$infofile")
			echo -e "${asupriority}\t${asupkg}\t${asupkgdescrip}" >> "$asupkginfo"
		done
	fi


	[ -f "$casppkginfo" ] && sort "$casppkginfo" -o "$casppkginfo" 	# sort the file for priority
	[ -f "$asupkginfo" ] && sort "$asupkginfo" -o "$asupkginfo" # sort the file for priority

	if [ -f "$casppkginfo" ] || [ -f "$asupkginfo" ]
	then
		# installs are available, write pref, it also will be picked up by ext attribute to make a smart group.
		defaults write "$prefs" InstallsAvail -string "Yes"
		installsavail="Yes"
	fi

	# some output to the log file if not --quiet
	if [ -f "$casppkginfo" ] && [ "$1" != "--quiet" ]
	then		
		secho "Casper pkgs waiting to be installed"
		secho "--------------------------------------"
		while read line
		do
			secho "$(echo "$line" | cut -f2)"
		done < "$casppkginfo"
		secho "--------------------------------------"
	fi
	
	if [ -f "$asupkginfo" ] && [ "$1" != "--quiet" ]
	then
		secho "swupdate pkgs waiting to be installed"
		secho "-------------------------------------"
		while read line
		do
			secho "$(echo "$line" | cut -f2)"
		done < "$asupkginfo"
		secho "-------------------------------------"
	fi
}

installCasperPkg()
{
	caspline="$1"
	casppkg=$(echo "$caspline" | cut -f2)
	infofile="$pkgdatafolder/${casppkg}.caspinfo"
	jamfinstallopts=""
	# check if a reboot is required by casper package, flag if it is.
	[ "$(cat "${infofile}.xml" | grep "<reboot_required>true</reboot_required>")" != "" ] && touch "$pkgdatafolder/.restart-required" 
	# check for fut and feu
	[ "$(cat "/Library/Application Support/JAMF/Waiting Room/$casppkg.cache.xml" | grep "<fut>true</fut>")" != "" ] && jamfinstallopts="$jamfinstallopts -fut"
	[ "$(cat "/Library/Application Support/JAMF/Waiting Room/$casppkg.cache.xml" | grep "<feu>true</feu>")" != "" ] && jamfinstallopts="$jamfinstallopts -feu"
	secho "jamf is installing $casppkg"
	$jb install "$jamfinstallopts" -package "$casppkg" -path "/Library/Application Support/JAMF/Waiting Room" -target /
	# (insert error checking)
	# remove from the waiting room

	if [ -d "/Library/Application Support/JAMF/Waiting Room/$casppkg" ]
	then
		# non-flat pkg
		rm -R "/Library/Application Support/JAMF/Waiting Room/$casppkg"
	else
		# flat pkg
		rm "/Library/Application Support/JAMF/Waiting Room/$casppkg"
	fi
	rm "/Library/Application Support/JAMF/Waiting Room/$casppkg.cache.xml"
}

installSoftware()
{
	secho "starting installation ..."
	
	# generate the update list tmp files
	buildUpdateLists --quiet
	
	# install all software	
	if [ -s "$casppkginfo" ] # there are casper updates waiting
	then	 
		if $bootstrapmode
		then
			# bootstrap mode doesn't need cocoadialog progress
			while read line
			do
				installCasperPkg "$line"
			done < "$casppkginfo"
		else
			(
				# use cocoadialog for gui
				currentpercent=0
				casptotal=$(cat "$casppkginfo" | wc -l)
				total=$(( casptotal * 100 ))		 		
		 		while read line
		 		do
					casppkgdescrip=$(echo "$line" | cut -f3)
					installCasperPkg "$line" & # background the jamf install, we'll fudge a progressbar
					caspinstallpid=$!
					# we are fudging a progress bar, count up to 100, increase bar, until done, then 
					for (( perfectcount=1; perfectcount<=100; perfectcount++ ))
					do
						percent=$(( ( (perfectcount + currentpercent) * 100 ) / total ))
						(( percent == 100 )) && percent=99	# we don't want out progressbar to finish prematurely
						echo "$percent Installing $casppkgdescrip ..."
						kill -0 "$caspinstallpid" 2> /dev/null
						[ "$?" != "0" ] && break # if it's done, break
						sleep 1
					done
					wait "$caspinstallpid" # if we have run out progress bar, wait for pid to complete.
					currentpercent=$(( currentpercent + 100 )) # add another 100 for each completed install				
				done < "$casppkginfo"
				echo "100 Installation complete"
				sleep 1
				[ -f "$pkgdatafolder/.restart-required" ] && echo "100 Restart is required"
				sleep 1
			) | "$cdialogbin" progressbar --icon installer --float --title "Installing Software" --text "Starting Installation..."  --icon-height "$iconsize" --icon-width "$iconsize" --width "500" --height "114"
		fi
	fi
	
	if [ -s "$asupkginfo" ] # there are apple updates waiting
	then
		asucount=0
		# bootstrap mode, no progress bars	
		if $bootstrapmode 
		then
			while read line
			do
				asupkg=$(echo "$line" | cut -f2)
				asupkgdescrip=$(echo "$line" | cut -f3)
				secho "softwareupdate is installing $asupkg ..."
				softwareupdate -v -i "$asupkg"
			done < "$asupkginfo"
		else
			(
				currentpercent=0
				asutotal=$(cat "$asupkginfo" | wc -l)
				total=$(( asutotal * 100 ))

				while read line
				do
					asupkg=$(echo "$line" | cut -f2)
					asupkgdescrip=$(echo "$line" | cut -f3)
					secho "softwareupdate is installing $asupkg ..."
					
					# spawn the update process, and direct output to tmpfile for parsing (we probably should use a named pipe here... future...)
					swupdcmd="softwareupdate -v -i $asupkg"
					swupdateout="$patchootmp/swupdateout-$RANDOM.tmp"
					softwareupdate -v -i "$asupkg" > "$swupdateout" &
					softwareupdatepid=$!
					# wait for the software update to finish, parse output of softwareupdate
					while kill -0 "$softwareupdatepid" > /dev/null 2>&1
					do
						sleep 1
						# get percent to update progressbar
						percentout=$(cat "$swupdateout" | grep "Progress:" | tail -n1 | awk '{print $2}' | sed 's/\%//g') 
						percent=$(( ( (percentout + currentpercent) * 100 ) / total ))
						echo "$percent Installing $asupkgdescrip ..."
					done
					currentpercent=$(( currentpercent + 100 )) # add another 100 for each completed install
					rm "$swupdateout"
				done < "$asupkginfo"
				echo "100 Installation complete"
				sleep 1
				[ -f "$pkgdatafolder/.restart-required" ] && echo "100 Restart is required"
				sleep 1
			) | "$cdialogbin" progressbar --icon installer --float --title "Installing Apple Software Updates" --text "Starting Installation..."  --icon-height "$iconsize" --icon-width "$iconsize" --width "500" --height "114"
		fi
	fi

	# flag for a recon since we've installed
	touch "$datafolder/.patchoo-recon-required"

	# check for restart
	if [ -f "$pkgdatafolder/.restart-required" ]
	then
		secho "restart is required by pkg"
		touch /tmp/.patchoo-restart
	fi

	# if there was an OS upgrade installed, flush out apple updates from system.
	if [ -f "$pkgdatafolder/.os-upgrade" ]
	then
		secho "flushing apple software updates..."
		rm -R /Library/Updates/*
		touch /tmp/.patchoo-restart
	fi

	# reset defer counters and flush pkgdata
	defaults write "$prefs" DeferCount -int 0
	defaults write "$prefs" InstallsAvail -string "No"
	installsavail="No"
	rm -R "$pkgdatafolder"
	rm /tmp/.patchoo-install
}

promptInstall()
{
	promptmode="$1"
	
	# build the lists of updates avail
	if $bootstrapmode
	then
		# if boostrapping, build updatelists (also sets installsavail)
		buildUpdateLists --quiet 
		return
	else
		buildUpdateLists
	fi
	
	# if there are no updates
	if [ "$installsavail" != "Yes" ]
	then
		secho "nothing to install"
		return
	fi

	# prompt in self service mode (no defer, and remove flag)
	if [ -f "$datafolder/.patchoo-selfservice-check" ]
	then
		promptmode="--selfservice"
		rm "$datafolder/.patchoo-selfservice-check"
	fi

	# there are waiting updates ... make a message for the user prompt	
	secho "prompting user..."
	message=""
	
	if [ -f "$casppkginfo" ]
	then
		while read line
		do
			makeMessage "$(echo "$line" | cut -f3)"	# 3rd column is pkg descript
		done < "$casppkginfo"
	fi

	if [ -f "$asupkginfo" ]
	then
		while read line
		do
			makeMessage "$(echo "$line" | cut -f3)"
		done < "$asupkginfo"
	fi

	# add warnings if there are firmware/os upgrade pkgs
	addWarnings

	case $promptmode in	
		"--logoutinstallsavail" )
			#
			# logout reminder prompt flags and 'returns' as we are already at a logout, so we can install directly within this session.
			#
			makeMessage ""
			makeMessage "$msginstalllater"
			answer=$(displayDialog "$message" "$msgtitlenewsoft" "$msgnewsoftware" "$lockscreenlogo" "Install and Restart..." "Install and Shutdown..." "Later")
			
			case $answer in			
				"Install and Restart..." )
					secho "user selected install and restart"
					touch /tmp/.patchoo-install
					touch /tmp/.patchoo-restart
					preInstallWarnings
					return
				;;				
				"Install and Shutdown..." )
					secho "user selected install and shutdown"
					touch /tmp/.patchoo-install
					touch /tmp/.patchoo-shutdown
					preInstallWarnings
					return
				;;
				"Later" )
					secho "user selected install later"
					return
				;;

				"timeout" )
					secho "timeout... will install and shutdown, the user is probably going home"
					touch /tmp/.patchoo-install
					touch /tmp/.patchoo-shutdown
					preInstallWarnings
					return
				;;
			esac
		;;
		
		"--selfservice" )
			#
			# self service we don't tell people to use self service, we don't update the defer counter 
			#
			answer=$(displayDialog "$message" "$msgtitlenewsoft" "$msgnewsoftware" "package" "Logout and Install..." "Cancel" )
		;;		
		
		*)
			#
			# this is the general prompt for the end of the update trigger run
			#
			
			# check to see if we can display a prompt
			consolestatus="$(checkConsoleStatus)"
			
			# some users just have blocking apps running constantly (Powerpoint / Keynote)
			# we need to prompt them at some stage.
			if $blockingappmode
			then
				if [ "$(echo "$consolestatus" | grep "BlockingApp:")" != "" ]
				then
					blockremain=$(( blockappthreshold - blockappcount ))
					if [ $blockremain -eq 0 ]
					then
						# blockingapp threshold exceeded, we will prompt user ...
						consolestatus="userloggedin"
						defaults write "$prefs" BlockingAppCount -int 0
					else
						(( blockappcount ++ ))
						secho "$consolestatus - preventing prompt to install."
						secho "blockingapp counter: $blockappcount, blockappthreshold: $blockappthreshold"
						defaults write "$prefs" BlockingAppCount -int $blockappcount
					fi
				fi
			fi

			# is userloggedin, we should display a prompt

			if [ "$consolestatus" == "userloggedin" ]
			then
				if $defermode
				then
					# check to see if they are allowed to defer anymore
					deferremain=$(( deferthreshold - defercount ))
					if [ $deferremain -eq 0 ] || [ $deferremain -lt 0 ]
					then
						# if the defercounter has run out, FORCED INSTALLATION! set timeout to 30 minutes
						dialogtimeout="1830"
						answer=$(displayDialog "$message" "$msgtitlenewsoft" "$msgnewsoftforced" "package" "Logout and Install...")
						# if it's nastymode (tm) we Logout and Install no matter what
						[ $nastymode ] && answer="Logout and Install..."
						secho "FORCING INSTALL!"
					else
						# prompt user with defer option
						makeMessage ""
						makeMessage "$msginstalllater"
						answer=$(displayDialog "$message" "$msgtitlenewsoft" "$msgnewsoftware" "package" "Later ($deferremain remaining)" "Logout and Install...")
						secho "deferral counter: $defercount, defer thresold: $deferthreshold"
					fi
				else
						# if we don't have deferals enabled
						makeMessage ""
						makeMessage "$msginstalllater"
						answer=$(displayDialog "$message" "$msgtitlenewsoft" "$msgnewsoftware" "package" "Later" "Logout and Install...")
				fi	
			else
				# there something preventing a dialog, don't display anything, return the consolestatus
				answer="$consolestatus"
			fi
		;;
	
	esac

	# process the answer.
	case $answer in
		
		"Logout and Install..." )
			# this flags for install, and logs out the user, logout policy picks up the install flag and does installations.
			secho "user selected install and logout..."
			# we need to logout the user
			touch /tmp/.patchoo-install
			echo $$ > /tmp/.patchoo-install-pid
			preInstallWarnings
			fauxLogout & # we spawn it, so if anything goes awry during install, the fauxLogout is a killswitch to put the mac back into line.
			# wait for the fauxlogout to do it's thing
			while [ ! -f /tmp/.patchoo-logoutdone ]
			do
				sleep 1
			done
			installSoftware
			rm /tmp/.patchoo-logoutdone
			return # once this finishes fauxLogut will handle logout
		;;
		
		"Later ($deferremain remaining)" )
			# this decreases counter and displays a notification bubble.
			secho "user selected install later, incrementing deferal counter.."
			(( defercount ++ ))
			defaults write "$prefs" DeferCount -int $defercount
			deferremain=$(( deferthreshold - defercount ))
			if [ $deferremain -eq 0 ]
			then
				secho "You cannot defer the installation any further. It will be forced on next notice" 8 "Installion Deferred" "caution"
			else
				secho "You can defer the installation $deferremain more times" 8 "Installion Deferred" "notice"
			fi
		;;

		"Later" )
			secho "user chose later" # no deferals
		;;

		"Cancel" )
			secho "user cancelled installation" # only available from self service
		;;


		* )
			# timeout, there are no logins, we are at the loginwindow, or screensaver is running / screen locked, or an app is blocking
			# we flag for a run on next notify run, and throw a recon
			secho "user missed this prompt - reason: $answer, flagged for reminder..."
			touch "$pkgdatafolder/.prompt-missed-$daystamp"
		;;
	
	esac
	
	# if we've cached new updates, recon the mac so it falls into the correct smart groups
	[ -f "$datafolder/.patchoo-recon-required" ] && jamfRecon
}

addWarnings()
{
	if [ -f "$pkgdatafolder/.os-upgrade" ]
	then
		makeMessage "$msgshortoswarn"
		return # we don't want other warnings
	fi	

	if [ -f "$pkgdatafolder/.fw-update" ]
	then
		makeMessage "$msgshortfwwarn"
	fi
}

preInstallWarnings()
{
	if [ -f "$pkgdatafolder/.os-upgrade" ]
	then
		displayDialog "$msgosupgradewarning" "OS Upgrade" "IMPORTANT NOTICE!" "caution" "I Understand... Install and Restart"
		touch /tmp/.patchoo-restart-forced
		return # we don't want other warnings
	fi	

	if [ -f "$pkgdatafolder/.fw-update" ]
	then
		displayDialog "$msgfirmwarewarning" "Firmware Update Warning" "IMPORTANT NOTICE!" "stop" "I Understand... Install and Restart"
		touch /tmp/.patchoo-restart-forced
	fi
}

logoutUser()
{
	secho "sending logout..."
	osascript -e "ignoring application responses" -e "tell application \"loginwindow\" to $(printf \\xc2\\xab)event aevtrlgo$(printf \\xc2\\xbb)" -e "end ignoring"
}

# fauxLogout - added to workaround cocoaDialog not running outside a user session on mavericks+ - https://github.com/patchoo/patchoo/issues/16 
# thanks to Jon Stovell - bits inspired and stolen from quit script - http://jon.stovell.info/
# loops through all user visible apps, quits, writes lsuielement changes to cocoa (prevent dock showing), uses ARD lockscreen to blank screen out.
getAppList()
(
	applist="$(sudo -u "$user" osascript -e "tell application \"System Events\" to return displayed name of every application process whose (background only is false and displayed name is not \"Finder\")")"
	echo "$applist"
)

quitAllApps()
(
	applist=$(getAppList)
	applistarray=$(echo "$applist" | sed -e 's/^/\"/' -e 's/$/\"/' -e 's/, /\" \"/g')
	eval set "$applistarray"
	for appname in "$@"
	do
		secho "trying to quit: $appname ..."
		sudo -u "$user" osascript -e "ignoring application responses" -e "tell application \"$appname\" to quit" -e "end ignoring"
	done
)

fauxLogout()
(
	secho "starting faux logout..."
	user=$(who | grep console | awk '{print $1}')
	waitforlogout=30
	tryquitevery=3
	while [ "$(getAppList)" != "" ]
	do
		for (( c=1; c<=(( waitforlogout / tryquitevery )); c++ ))
		do
			quitAllApps
			#check if all apps are quit break if so, otherwise fire every $tryquitevery
			[ "$(getAppList)" == "" ] && break
			sleep $tryquitevery
		done
		if [ "$(getAppList)" != "" ]
		then
			# if we still haven't quit all Apps
			dialogtimeout=60
			secho "apps are still running after $waitforlogout seconds, prompting user and trying quit loop again.."
			displayDialog "Ensure you have saved your documents and quit any open applications. You can Force Quit applications that aren't responding by pressing CMD-SHIFT-ESC." "Logging out" "The Logout process has stalled" "caution" "Continue Logout"
			quitAllApps
		fi
	done
	
	# thanks mm2270 (https://github.com/mm2270) for this technique!
	# Modified by Franton to deal with System Integrity Protection.
	# Copy the lockscreen.app with cp elsewhere on the system and modify THAT instead.
	cp -r /System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/Support/LockScreen.app $patchootmp/LockScreen.app
	 
	# move the standard lock logo out of lockscreen app (we don't want a big padlock)
	mv $patchootmp/LockScreen.app/Contents/Resources/Lock.jpg $patchootmp/LockScreen.app/Contents/Resources/Lock.jpg.backup
	
	if [ -f "$lockscreenlogo" ]
	then
		sips -s format png --resampleWidth 512 "$lockscreenlogo" --out "$patchootmp/Lock.jpg" 2> /dev/null # it will throw an error about and png being name jpg
		mv "$patchootmp/Lock.jpg" $patchootmp/LockScreen.app/Contents/Resources/Lock.jpg
	fi

	# lock screen
	$patchootmp/LockScreen.app/Contents/MacOS/LockScreen & 2> /dev/null
	sleep 1

	# makes changes to cocoaDialog
	defaults write "${cdialog}/Contents/Info.plist" LSUIElement -int 0
	defaults write "${cdialog}/Contents/Info.plist" LSUIPresentationMode -int 3
	chmod 644 "${cdialog}/Contents/Info.plist"

	touch /tmp/.patchoo-logoutdone
	installpid=$(cat /tmp/.patchoo-install-pid)
	secho "fauxlogout done, screen locked (my pid: $$) waiting installs (pid: $installpid)..."
	while ps -p "$installpid" > /dev/null
	do
		sleep 1
	done
	# putting it back order
	rm /tmp/.patchoo-install-pid
	rm /tmp/.patchoo-logoutdone
	# undo changes to cocoaDialog
	defaults write "${cdialog}/Contents/Info.plist" LSUIElement -int 1
	defaults write "${cdialog}/Contents/Info.plist" LSUIPresentationMode -int 0
	chmod 644 "${cdialog}/Contents/Info.plist"
	# unlock and logout
	killall LockScreen
	
	# Clean up modified lockscreen app
	rm -rf $patchootmp/LockScreen.app
	
	logoutUser # the logout policy will handle recon / restart / shutdown requests

)

processLogout()
{
	if [ "$installsavail" == "Yes" ]
	then
		# if <10.9 we can use this can prompt outside a user session with cdialog
		if $displayatlogout
		then
			promptInstall --logoutinstallsavail
			if [ -f /tmp/.patchoo-install ]
			then
				# user chose to install updates
				preInstallWarnings
				installSoftware
			else
				# user chose later
				return
			fi
		fi
	fi
	
	# process a restart or shutdown
	if [ -f "$datafolder/.patchoo-recon-required" ]
	then
		if [ -f /tmp/.patchoo-restart ] || [ -f /tmp/.patchoo-shutdown ]
		then
			# run on recon on reboot
			secho "flagged for a post boot recon"
		else
			# otherwise no restart required, we can do it in the background whilst user logs back in
			jamfRecon &
		fi
	fi
	
	if [ -f /tmp/.patchoo-restart-forced ]
	then
		touch /tmp/.patchoo-restart # forced restart to trump shutdown, need restarts for FW and OS Upgrades
		[ -f /tmp/.patchoo-shutdown ] && rm /tmp/.patchoo-shutdown # we don't want fwupdates to install and shutdown
		rm /tmp/.patchoo-restart-forced
	fi

	if [ -f /tmp/.patchoo-shutdown ] 
	then
		secho "shutting down now!"
		[ -f /tmp/.patchoo-restart ] && rm /tmp/.patchoo-restart # remove this, shutdown trumps restart request by a pkg
		rm /tmp/.patchoo-shutdown
		shutdown -h now &
	fi

	if [ -f /tmp/.patchoo-restart ]
	then
		secho "restarting now!"
		rm /tmp/.patchoo-restart
		shutdown -r now &
	fi
}

jamfPolicyUpdate()
{
	# if we are using the swrelease triggers, get groups and run the trigger
	if $patchooswreleasemode
	then
		getGroupMembership
		if [ "$groupid" != "0" ]
		then
			secho "jamf is firing ${updatetrigger[$groupid]} trigger ..." 
			$jb policy -event "${updatetrigger[$groupid]}"
		fi
	fi
	# once we've got run our group trigger, run the standard...
	secho "jamf is firing ${updatetrigger[0]} trigger ..."
	$jb policy -event "${updatetrigger[0]}"

}

getGroupMembership()
{
	groupid=0
	# jss group file, we cache this in a central location so we can minimise number of hits on the jss for an update session.
	if [ ! -f "$jssgroupfile" ]
	then
		secho "getting computer group membership ..."
		curl $curlopts -H "Accept: application/xml" -s -u "$apiuser:$apipass"  "${jssurl}JSSResource/computers/udid/$udid" | xpath //computer/groups_accounts/computer_group_memberships[1] 2> /dev/null | sed -e 's/<computer_group_memberships>//g;s/<\/computer_group_memberships>//g;s/<group>//g;s/<\/group>/\n/g' > "$jssgroupfile"
	fi
	for checkgroup in ${jssgroup[@]}
	do
		# we don't check against the production
		if [ "$checkgroup" != "----PRODUCTION----" ]
		then
			# if find matching group, return out 
			[ "$(cat "$jssgroupfile" | grep "$checkgroup")" != "" ] && return
		fi
		(( groupid ++ ))
	done
	# if we get to here we haven't matched a group, this mac is just production
	groupid=0
}

patchooStart()
{
	secho "starting triggered patchoo run!"
	jamfPolicyUpdate
}

checkUpdatesSS()
{
	spawnScript
	touch "$datafolder/.patchoo-selfservice-check"
	secho "You will be notified if any installations are available" 4 "Checking for new software" "notice"
	jamfPolicyUpdate
	if [ -f "$datafolder/.patchoo-selfservice-check" ] # the flag is still here, no promptforupdates!
	then
		displayDialog "There is no new software available at this time." "No New Software Available" "" "$lockscreenlogo" "Ok"
		rm "$datafolder/.patchoo-selfservice-check"
	fi
}

promptInstallSS()
{
		spawnScript		# spawn so policy can finish and Self Service.app doesn't block logout.
		promptInstall --selfservice
}

remindInstall()
{
	# run this on every120, scoped to a smart group
	if [ "$installsavail" == "Yes" ]
	then		
		if $defermode
		then
			# naughty users realised they could ignore the prompts... no more... if you miss all prompts in a day, the defer counter is increased the next day. bam.
			yesterdaystamp=$(( daystamp - 1 ))
			if [ -f "$pkgdatafolder/.prompt-missed-$yesterdaystamp" ]
			then
				(( defercount ++ ))
				secho "user missed prompts yesterday, increasing defer count to $defercount"
				defaults write "$prefs" DeferCount -int $defercount
				rm "$pkgdatafolder/.prompt-missed-$yesterdaystamp"
			fi	
			if [ -f "$pkgdatafolder/.prompt-missed-$daystamp" ]
			then
				# if there is missed prompt flag for today, bring up the reminder
				rm "$pkgdatafolder/.prompt-missed-$daystamp"
				promptInstall
			else
				# otherwise, a notify bubble
				deferremain=$(( deferthreshold - defercount ))
				if [ $deferremain -eq 0 ]
				then
					# no deferrals left. you gotta do it on the next notice!
					secho "You can not defer the installation further. Launch Self Service and select Install New Software as soon as possible" 8 "$msgtitlenewsoft" "caution"
				else
					secho "Please launch Self Service and select Install New Software" 8 "$msgtitlenewsoft" "notice"
				fi
			fi
		else
			# no defer mode to process... just show a bubble
			secho "Please launch Self Service and select Install New Software" 8 "$msgtitlenewsoft" "notice"
		fi
	fi
}	

startup()
{
	# post reboot after install, recon on startup.
	[ -f "$datafolder/.patchoo-recon-required" ] && jamfRecon
}


updateHandler()
{
	jamfRecon
	jamfPolicyUpdate 
	installsavail=$(defaults read "$prefs" InstallsAvail  2> /dev/null) 	# check if updates are avaialble
	
	while [ "$installsavail" == "Yes" ]
	do
		installSoftware
		if [ -f /tmp/.patchoo-restart ]
		then
			secho "restarting now!"
			rm /tmp/.patchoo-restart
			reboot
			return
		fi
		# we will either reboot and pickup again at loginwindow
		# or run another update and install loop
		jamfRecon
		jamfPolicyUpdate
		installsavail=$(defaults read "$prefs" InstallsAvail 2> /dev/null)
	done

	# no more updates stop bootstrap
	if [ -f "${pddeployreceipt}" ]
	then
		touch "${pddeployreceipt}.updated" 	# touch a receipt, can be used for smartgroup notification
		jamfRecon
	fi
	secho "update process complete!"
	sleep 10
	rm "$bootstrapagent"
	rm /Library/Scripts/patchoo.sh
	killall jamfHelper
	# all done loginwindow is unlocked
	reboot &
}

#
#  deploy functions
#

checkAndReadProvisionInfo()
{
	secho "reading provisioning info from jss..."
	pdprovisiontmp="$patchootmp/patchooprovisioninfo.tmp"
	[ -f "$pdprovisiontmp" ] && rm "$pdprovisiontmp"
	
	# read the values as required, if missing, return false
	pdprovisioninfo=true	
	if [[ $pdusebuildea = "true" ]];
	then
		patchoobuild=$( curl $curlopts -H "Accept: application/xml" -s -u ${apiuser}:${apipass} ${jssurl}JSSResource/computers/udid/$udid/subset/extension_attributes | xpath "//*[name='$pdbuildea']/value/text()" 2> /dev/null)
		# error checking
		secho "patchoobuild:  $patchoobuild"
		echo "Extension Attribute: $patchoobuild" >> $pdprovisiontmp
		[ "$patchoobuild" == "" ] && pdprovisioninfo=false
	fi

	if [[ $pdusedepts = "true" ]];
	then
		department=$( curl $curlopts -H "Accept: application/xml" -s -u ${apiuser}:${apipass} ${jssurl}JSSResource/computers/udid/$udid/subset/location | xpath "//computer/location/department/text()" 2> /dev/null )
		# error checking
		secho "department:  $department"
		echo "Department: $department" >> $pdprovisiontmp
		[ "$department" == "" ] && pdprovisioninfo=false
	fi

	if [[ $pdusebuildings = "true" ]];
	then
		building=$( curl $curlopts -H "Accept: application/xml" -s -u ${apiuser}:${apipass} ${jssurl}JSSResource/computers/udid/$udid/subset/location | xpath "//computer/location/building/text()" 2> /dev/null)
		# error checkingx
		secho "building:  $building"
		echo "Building: $building" >> $pdprovisiontmp
		[ "$building" == "" ] && pdprovisioninfo=false
	fi

	if [[ $pdprovisioninfo = "true" ]];
	then
		return 0
	else
		return 1
	fi
}

promptAndSetComputerName()
{
	# this computer must existing in the JSS... as we've been enrolled!
	computername=$(curl $curlopts -H "Accept: application/xml" -s -u "$apiuser:$apipass" "${jssurl}JSSResource/computers/udid/$udid/subset/general" | xpath "//computer/general/name/text()" 2> /dev/null)
	if $pdsetcomputername
	then
		secho "current computername is $computername"
		validcomputername=false
		until $validcomputername
		do 
			choice=$( $cdialogbin inputbox --title "Computer Name" --informative-text "Please confirm this Mac's computername" --text $computername --icon-file "$lockscreenicon" --string-output --float --button1 "Confirm and Set" )
			newcomputername=$( echo $choice | awk '{ print $4 }' )
			if [ "$newcomputername" == "" ]
			then
				$cdialogbin msgbox --title "Alert" --informative-text "The computer name cannot be blank" --icon-file "$lockscreenicon" --float --timeout 90 --button1 "Oops"
				continue
			else
				# lookup jss to ensure computername isn't in use
				udidlookup=$(curl $curlopts -H "Accept: application/xml" -s -u "$apiuser:$apipass" "${jssurl}JSSResource/computers/name/$(echo "$newcomputername" | sed -e 's/ /\+/g')/subset/general" | xpath "//computer/general/mac_address/text()" 2> /dev/null | sed 's/:/./g' | tr '[:upper:]' '[:lower:]')
				if [ "$udidlookup" == "" ] || [ "$udidlookup" == "$udid" ] # no entry, or our entry - ok to go
				then
					computername="$newcomputername"
					validcomputername=true
				else
					# another computer with this name exists in the JSS
					$cdialogbin msgbox --title "Alert" --icon-file "$lockscreenicon" --informative-text "A Mac named $newcomputername already exists in the JSS." --float --timeout 90 --button1 "Oops"

				fi
			fi
		done
		# set the computername with scutil
		secho "setting computername to $computername"
		scutil --set ComputerName "$computername"
		scutil --set LocalHostName "$computername"
		scutil --set HostName "$computername"
	fi
}

promptProvisionInfo()
{
	patchoobuildeatmp="$patchootmp/patchoobuildeatmp.xml"
	depttmp="$patchootmp/depttmp.xml"
	buildingtmp="$patchootmp/buildingtmp.xml"
	choicetmp="$patchootmp/choicetmp.tmp"

	promptAndSetComputerName

	if checkAndReadProvisionInfo
	then
		secho "prompting user to change provision info..."
		provisiondetails=$(cat "$pdprovisiontmp")
		changeprovisioninfoprompt=$( $cdialogbin msgbox --title "Mac Provisioning Information" --icon-file "$lockscreenlogo" --text "This Mac has the following provisioning information:" --informative-text "$provisiondetails" --button1 "Continue" --button2 "Change" --string-output )

		if [[ "$changeprovisioninfoprompt" == "Continue" ]];
		then
			deployready="true"
			return 0
		fi
	else
		secho "provisioning information incomplete..."
		skipprompt=$( $cdialogbin msgbox --title "Alert" --icon-file "$lockscreenlogo" --informative-text "This Mac has incomplete provisioning information" --string-output --timeout 90 --button1 "Configure" --button2 "Skip" )
		if [[ "$skipprompt" == "Skip" ]];
		then
			deployready="true"
			return 0
		fi
	fi

	if [[ $pdusebuildea = "true" ]];
	then
		#read patchoobuilds
		ea=$( echo "$pdbuildea" | sed -e 's/ /\+/g' )
		patchoobuildchoicearray=$( curl $curlopts -H "Accept: application/xml" -s -u ${apiuser}:${apipass} --request GET ${jssurl}JSSResource/computerextensionattributes/name/$ea )
		patchoobuildchoicearray=$( echo $patchoobuildchoicearray | xpath //computer_extension_attribute/*/popup_choices/* 2> /dev/null )
		patchoobuildchoicearray=$( echo $patchoobuildchoicearray | sed -e 's/<choice>//g' | sed -e $'s/<\/choice>/\\\n/g' | tr '\n' ',' )
		patchoobuildchoicearray=$( echo $patchoobuildchoicearray | sed 's/..$//' )
		
		OIFS=$IFS
		IFS=$','
		# error checking
		for line in "${patchoobuildchoicearray[@]}"
		do
			echo "$line" >> "$choicetmp"
		done
		
		# pop up choices dialog box. strip button report as we only want the department name.
		patchoobuildvalue=$( "$cdialogbin" dropdown --icon-file "$lockscreenlogo" --title "Deployment EA" --text "Please Choose:" --items $(< $choicetmp) --string-output --button1 "Ok" )
		patchoobuildvalue=$( echo $patchoobuildvalue | sed -n 2p )
		IFS=$OIFS
		
		# error checking
		secho "EA value: $patchoobuildvalue"
		rm "$choicetmp"
	fi

	if [[ $pdusedepts = "true" ]];
	then
		#read dept choices	
		deptchoicearray=$(curl $curlopts -H "Accept: application/xml" -s -u ${apiuser}:${apipass} --request GET ${jssurl}JSSResource/departments | xpath //departments/department/name 2> /dev/null | sed -e 's/<name>//g' | sed -e $'s/<\/name>/\\\n/g' | tr '\n' ',')
		deptchoicearray=$( echo $deptchoicearray | sed 's/..$//' )

		OIFS=$IFS
		IFS=$','
		# error checking
		for line in "${deptchoicearray[@]}"
		do
			echo "$line" >> "$choicetmp"
		done
		
		# pop up choices dialog box. strip button report as we only want the department name.
		deptvalue=$( $cdialogbin dropdown --icon-file "$lockscreenlogo" --title "Department" --text "Please Choose:" --items $(< $choicetmp) --string-output --button1 "Ok" )
		deptvalue=$( echo $deptvalue | sed -n 2p )
		IFS=$OIFS
		
		# error checking
		secho "Department value: $(echo "$deptvalue")"
		rm "$choicetmp"
	fi

	if [[ $pdusebuildings = "true" ]];
	then
		#read building choices	
		buildingchoicearray=$(curl $curlopts -H "Accept: application/xml" -s -u ${apiuser}:${apipass} --request GET ${jssurl}JSSResource/buildings | xpath //buildings/building/name 2> /dev/null | sed -e 's/<name>//g' | sed -e $'s/<\/name>/\\\n/g' | tr '\n' ',')
		buildingchoicearray=$( echo $buildingchoicearray | sed 's/..$//' )
		OIFS=$IFS
		IFS=$','
		# error checking
		for line in "${buildingchoicearray[@]}"
		do
			echo "$line" >> "$choicetmp"
		done
		
		# pop up choices dialog box. strip button report as we only want the building name.
		buildingvalue=$( $cdialogbin dropdown --icon-file "$lockscreenlogo" --title "Building" --text "Please Choose:" --items $(< $choicetmp) --string-output --button1 "Ok" )
		buildingvalue=$( echo $buildingvalue | sed -n 2p )
		IFS=$OIFS
		
		# error checking
		secho "Building value: $(echo "$buildingvalue" )"
		rm "$choicetmp"
	fi

	# write out xml for put to api
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
<computer>
<extension_attributes>
<attribute>
<name>$pdbuildea</name>
<value>$patchoobuildvalue</value>
</attribute>
</extension_attributes>
</computer>
" > "$patchoobuildeatmp"
	
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
<computer>
<location>
<department>$deptvalue</department>
</location>
</computer>
" > "$depttmp"
	
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
<computer>
<location>
<building>$buildingvalue</building>
</location>
</computer>
" > "$buildingtmp"

	while true
	do
		if [ "$pdapiadminname" == "" ]
		then
			entry=$( $cdialogbin inputbox --title "Username" --icon-file "$lockscreenlogo" --informative-text "Please enter your username:" --text $hardcode --string-output --button1 "Ok" )
			tmpapiadminuser=$( echo $entry | awk '{ print $2 }' )
		else
			tmpapiadminuser="$pdapiadminname"
		fi		
		if [ "$pdapiadminpass" == "" ]
		then	
			entry=$( $cdialogbin inputbox --title "Password" --icon-file "$lockscreenlogo" --informative-text "Please enter your password:" --text $hardcode --string-output --button1 "Ok" )
			tmpapiadminpass=$( echo $entry | awk '{ print $2 }' )	
		else
			tmpapiadminpass="$pdapiadminpass"
		fi
		
		# put the xml to api
		retryauth=false

		if $pdusebuildea
		then
			putresult=$(curl $curlopts -H "Accept: application/xml" -s -u "$tmpapiadminuser:$tmpapiadminpass" "${jssurl}JSSResource/computers/udid/$udid/subset/extensionattributes" -T "$patchoobuildeatmp" -X PUT | grep "requires user authentication")
			[ "$putresult" != "" ] && retryauth=true
		fi

		if $pdusedepts
		then
			putresult=$(curl $curlopts -H "Accept: application/xml" -s -u "$tmpapiadminuser:$tmpapiadminpass" "${jssurl}JSSResource/computers/udid/$udid/subset/location" -T "$depttmp" -X PUT | grep "requires user authentication")
			[ "$putresult" != "" ] && retryauth=true
		fi

		if $pdusebuildings
		then
			putresult=$(curl $curlopts -H "Accept: application/xml" -s -u "$tmpapiadminuser:$tmpapiadminpass" "${jssurl}JSSResource/computers/udid/$udid/subset/location" -T "$buildingtmp" -X PUT | grep "requires user authentication")
			[ "$putresult" != "" ] && retryauth=true
		fi

		if $retryauth
		then
			entry=$( $cdialogbin msgbox --width 400 --height 140 --title "Alert" --informative-text "The admin username or password was incorrect" --string-output --icon hazard --float --timeout 90 --button1 "Ok" --button2 "Skip" )
			tryagain=$( echo $entry | awk '{ print $2 }' )
			[ "$tryagain" == "Ok" ] && continue # loop again
		fi
		# if we are here, all good to go
		deployready=true
		break
	done
}

deploySetup()
{
	# run on enrollment complete, setups up deploy process
	secho "setting up patchoo deploy .."
	touch "$pddeployreceipt"
	deployready=false

	$cdialogbin msgbox --width 400 --height 140 --icon-file "$lockscreenlogo" --title "Deployment" --informative-text "$msgpatchoodeploywelcome" --string-output --float --timeout 10 --button1 "Ok"

	until $deployready
	do
		if $pdpromptprovisioninfo
		then
			# prompt the console user and update the jss
			promptProvisionInfo
		else
			# we don't prompt, this mac will go into the holding pattern on reboot if it doesn't have provision info
			deployready=true
		fi
	done

	# Clean up any existing bootstrap
	srm /Library/Preferences/$bootstrapagent
	srm /Library/Scripts/patchoo.sh

	bootstrapSetup # setup bootstrap bits

	secho "patchoo deploy is ready"
	
	if [ "$(checkConsoleStatus)" == "userloggedin" ] # if a user is logged in, prompt and restart... otherwise we'll sort that via a launchd or other method
	then
		$cdialogbin msgbox --icon-file "$lockscreenlogo" --title "Provisioning" --informative-text "Ready to provision. This Mac will restart in 2 minutes" --string-output --float --timeout 120 --button1 "Restart"
		#logoutUser
		#sleep 10 # not pretty
		reboot
	fi
}

deployHandler()
{
	# start patchooDeploy, read provision info and loop until we have it
	secho "starting deployment..."
	until checkAndReadProvisionInfo
	do
		# if we don't have provisioning info, check flag
		if [ ! -f "${pddeployreceipt}.holdingpattern" ]
		then
			# write receipt, and recon so mac lands in holding patt group and admin gets notification
			touch "${pddeployreceipt}.holdingpattern"
			jamfRecon
		fi
		secho "$msgbootstapdeployholdingpattern"
		sleep 60 # waiting 60 secs and try again
	done

	#remove the flag
	[ -f "${pddeployreceipt}.holdingpattern" ] && rm "${pddeployreceipt}.holdingpattern"

	secho "provision information complete, starting deployment ..."
	sleep 3
	
	# run recurring trigger before we start deploy, in case we have stuff we need to do on that - once per computer etc.
	secho "firing recurring checkin trigger ..."
	$jb policy
	secho "firing deploy trigger ..."
	$jb policy -event "deploy"
	
	if $pdusebuildea
	then
		secho "firing deploy-${patchoobuild} trigger ..."
		$jb policy -event "deploy-${patchoobuild}"	# calling our build specific trigger eg. deploy-management, deploy-studio
	fi
	
	if $department
	then
		secho "firing deploy-${department} trigger ..."
		$jb policy -event "deploy-${department}"	# calling our build specific trigger eg. deploy-management, deploy-studio
	fi
	
	if $building
	then
		secho "firing deploy-${building} trigger ..."
		$jb policy -event "deploy-${building}"		# calling our build specific trigger eg. deploy-management, deploy-studio
	fi
	
	installsavail=$(defaults read "$prefs" InstallsAvail  2> /dev/null)  # are installations cached by patchoo polcies, during our deploy?
	
	if [ "$installsavail" == "Yes" ]
	then
		installSoftware
	fi
	
	# deploy finished, rebooting to start update
	secho "deployment process has finished, restarting to start update process ..."
	rm "$pddeployreceipt"
	touch "${pddeployreceipt}.done"
	sleep 10
	reboot
}

deployGroup()
{
	secho "running deploygroup items..."
	while [[ $# > 0 ]]
	do
 		triggerorpolicy="$1"
 		shift
 		if [ "$triggerorpolicy" != "" ]
 		then
	 		secho "looking up $triggerorpolicy against jss..."
			policyid=$(curl $curlopts -H "Accept: application/xml" -s -u "$apiuser:$apipass"  "${jssurl}JSSResource/policies/name/$(echo "$triggerorpolicy" | sed -e 's/ /\+/g')" -X GET | xpath //policy/general/id 2> /dev/null | sed -e 's/<id>//;s/<\/id>//')
			if [ "$policyid" != "" ]
			then
				secho "jamf calling policy id $policyid"
				$jb policy -id "$policyid"
			else
				# if there's no id, lets call a trigger
				secho "jamf firing trigger $triggerorpolicy"
				$jb policy -event "$(echo "$triggerorpolicy" | sed -e 's/ /\_/g')"
			fi
		fi
	done
}

bootstrap()
{
	spawnScript
	# this starts the bootstrap deploy and update process.
	if [ -f "$pddeployreceipt" ] && [ ! -f "${pddeployreceipt}.done" ]
	then
		deployHandler
	else
		updateHandler
	fi
}

bootstrapSetup()
{
# write out a launchagent to call bootstrap helper

bootstrappagentplist='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.github.patchoo-bootstrap</string>
	<key>RunAtLoad</key>
	<true/>
	<key>LimitLoadToSessionType</key>
	<string>LoginWindow</string>
	<key>ProgramArguments</key>
	<array>
        <string>/Library/Scripts/patchoo.sh</string>
        <string>''</string>
        <string>''</string>
        <string>''</string>
        <string>--bootstraphelper</string>
	</array>
</dict>
</plist>'

	echo "$bootstrappagentplist" > "$bootstrapagent"
	# set permissions for agent
	chown root:wheel "$bootstrapagent"
	chmod 644 "$bootstrapagent"
	# copy the script to local drive
	cp "$0" /Library/Scripts/patchoo.sh
	chown root:wheel /Library/Scripts/patchoo.sh
	chmod 700 /Library/Scripts/patchoo.sh
	# unset any loginwindow autologin
	defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser ""
	secho "bootstrap setup done, you need to restart"
}

bootstrapSetupDeploy()
{
# write out a launchagent to call bootstrap helper

bootstrappagentplist='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.github.patchoo-bootstrap</string>
	<key>RunAtLoad</key>
	<true/>
	<key>LimitLoadToSessionType</key>
	<string>LoginWindow</string>
	<key>ProgramArguments</key>
	<array>
        <string>/Library/Scripts/patchoo.sh</string>
        <string>''</string>
        <string>''</string>
        <string>''</string>
        <string>--deploysetup</string>
	</array>
</dict>
</plist>'

	echo "$bootstrappagentplist" > "$bootstrapagent"
	# set permissions for agent
	chown root:wheel "$bootstrapagent"
	chmod 644 "$bootstrapagent"
	# copy the script to local drive
	cp "$0" /Library/Scripts/patchoo.sh
	chown root:wheel /Library/Scripts/patchoo.sh
	chmod 700 /Library/Scripts/patchoo.sh
	# unset any loginwindow autologin
	defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser ""
	secho "bootstrap setup done, you need to restart"
}

bootstrapHelper()
{
	# patchoo bootstrap helper
	#
	# lock immediately
	"$jamfhelper" -windowType fs -description "$msgbootstrap" -icon "$lockscreenlogo" &

	# the local helper will handle caffination and enforcing management in case jss not reachable immediately

	# caffeinate this mac (? 10.7 ?)
	caffeinate -d -i -m -u &
	caffeinatepid=$!

	secho "waiting for jss.."
#	until jamf checkJSSConnection
#	do
		sleep 2
#	done

	killall jamfHelper

	# trigger the bootstrap policy
	$jb policy -event "bootstrap" &

	# these messages will be ignored in the jamf.log, the previous entry will be displayed at the lockscreen
	ignoremessages=("The management framework will be enforced" "Checking for policies triggered by")

	while [ -f "$bootstrapagent" ]	# whilst the agent exists, we are in bootstrap mode
	do
		tailvalue=1
		newmessage=""
		while [ "$newmessage" == "" ]
		do
			newmessage="$(tail -n${tailvalue} /var/log/jamf.log | head -n1 | cut -d' ' -f 4- | sed -e $'s/: /\\\n\\\n/g')"
			for ignoremessage in ${ignoremessages[@]}
			do
				if [ "$(echo "$newmessage" | grep "$ignoremessage")" != "" ]
				then
					# we've found an ignore message, bounce up an entry.
					newmessage=""
					(( tailvalue ++ ))
				fi
			done
		done

		if [ "$message" != "$newmessage" ] # if the message has updated, change login screen
		then
			message="$newmessage"
			displaymsg="$msgbootstrap
$message"
			killall jamfHelper
			"$jamfhelper" -windowType fs -description "$displaymsg" -icon "$lockscreenlogo" &
		fi
		sleep 3 # check for new message every 3 seconds
	done
	
	# uncaffeninate
	kill "$caffeinatepid"
}

jamfRecon()
{
	secho "jamf is running a recon ..."
	if [ "$1" == "--feedback" ]
	then
		( $jb recon ) | "$cdialogbin" progressbar --icon sync --float --indeterminate --title "Casper Recon" --text "Updating computer inventory..."  --icon-height "$iconsize" --icon-width "$iconsize" --width "500" --height "114" 
	else
		$jb recon
	fi		
	# if there is flag, remove it
	[ -f "$datafolder/.patchoo-recon-required" ] && rm "$datafolder/.patchoo-recon-required"
	secho "recon finished"
}

cleanUp()
{
	rm -R "$patchootmp"
	[ -f "$jssgroupfile" ] && rm "$jssgroupfile" 	# cached group membership
	[ "$spawned" == "--spawned" ] && rm "$0" 	#if we are spawned, eat ourself.
	IFS=$OLDIFS
}

###########

echo "$name $version $mode - $(date "+%a %b %d %H:%M:%S")"

# parse modes
case $mode in
	
	"--cache" )
		# run after caching package in policy to add metadata.
		cachePkg
	;;

	"--checkasu" )
		# run periodically on update trigger
		checkASU
	;;

	"--promptinstall" )
		# install mode prompts user to install, called post cache.
		promptInstall
	;;
	
	"--promptinstallss" )
		# prompt from selfservice
		promptInstallSS
	;;

	"--checkupdatess" )
		# trigger update from selfservice
		checkUpdatesSS
	;;

	"--remind" )
		# run on every120
		remindInstall
	;;

	"--startup" )
		#run on startup, recon if we've just installed updates that required a reboot
		startup
	;;
	
	"--logout" )
		# this is triggered by the logout hook, we do out installs on logout
		processLogout
	;;

	"--patchoostart" )
		# this starts the patchoo update process, triggered by -trigger patchoo
		patchooStart
	;;

	"--bootstrapsetup" )
		bootstrapSetup
		# setups up the bootstrap launchagent, copies script and turns off autologin
	;;

	"--bootstraphelper" )
		# used internally by launchagent for loginwindow session, drives the loginwindow messages
		bootstrapHelper
	;;

	"--bootstrap" )
		# called by the launch agent, drives the bootstrap process (deploy and updates)
		bootstrap
	;;
	
	"--deploybootstrap" )
		# setups up deployment bootstrap, run on enrollment complete.
		bootstrapSetupDeploy
	;;
	
	"--deploysetup" )
		# setups up deployment, run on enrollment complete
		deploySetup
	;;

	"--deploygroup" )
		# group deploy policies together - paramters are executed - pass either policies or triggers
		deployGroup "$5" "$6" "$7" "$8" "$9" "${10}" "${11}"
	;;

	*)
		secho "malfunction. I dont know how to $mode"
	;;

esac

# tidy up any leftovers
cleanUp

exit 0
