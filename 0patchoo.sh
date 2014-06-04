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

# DEBUG STUFF
#set -x	# DEBUG. Display commands and their arguments as they are executed
#set -v	# VERBOSE. Display shell input lines as they are read.
#set -n	# EVALUATE. Check syntax of the script but dont execute
#debuglogfile=/DEBUGpatchoo-$(date "+%F_%H-%M-%S").log
#exec > $debuglogfile 2>&1

#
# start configurable settings
#

name="patchoo"
version="0.991"

# read only api user please!
apiuser="apiuser"
apipass="apipassword"

datafolder="/Library/Application Support/patchoo"
pkgdatafolder="$datafolder/pkgdata"
prefs="$datafolder/com.github.patchoo"
cdialog="/Applications/Utilities/cocoaDialog.app/Contents/MacOS/cocoaDialog"
jamfhelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

# if you are using a self signed cert for you jss, tell curl to allow it.
selfsignedjsscert=true

# users can defer x update prompts
defermode=true
defaultdeferthresold="10"

# users running blocking apps will have x number of prompts delayed, ie will not run on prompt/remindto install until threshold is reached
blockingappmode=true
defaultblockappthreshold="2" # if missed at lunch, then 2x2 hours later... should prompt in afternoon?

# if these apps are running notifications will not be displayed, presentation apps ? 
blockingapps=( "PowerPoint.app" "Keynote.app" )

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
patchooswreleasemode=true
updatetrigger[0]="update"
updatetrigger[1]="update-dev"
updatetrigger[2]="update-beta"

# if using patchoo asu release mode these will be appended to computer's SoftwareUpdate server catalogs as per reposado forks -- if not using asu release mode the computer's SwUpdate server will remain untouched.
# eg. http://swupdate.your.domain:8088/content/catalogs/others/index-leopard.merged-1${asureleasecatalogs[i]}.sucatalog
patchooasureleasemode=true
asureleasecatalog[0]="prod"
asureleasecatalog[1]="dev"
asureleasecatalog[2]="beta"

#
# configure user prompts and feedback.
#
msgtitlenewsoft="New Software Available"
msgnewsoftware="The following new software is available"
msginstalllater="(You can perform the installation later via Self Service)"
msgnewsoftforced="The following software must be installed now!"
msgbootstrap="Mac is being updated. Do not interrupt or power off."
msgshortfwwarn="
IMPORTANT: A firmware update will be installed.
Ensure you connect AC power before starting the update process."
msgshortoswarn="
IMPORTANT: A major OSX upgrade will be performed.
Ensure you connect AC power before starting the update process.
It could take up to 90 minutes to complete."
msgfirmwarewarning="
Firmware updates will be installed after your computer restarts.

Please ensure you are connected to AC Power! Do NOT touch any keys or the power button! A long tone will sound and your screen may be blank for up to 5 minutes.

IT IS VERY IMPORTANT YOU DO NOT INTERRUPT THIS PROCESS AS IT MAY LEAVE YOUR MAC INOPERABLE"
msgosupgradewarning="
Your computer is peforming a major OSX upgrade.

Please ensure you are connected to AC Power! Your computer will restart and the OS upgrade process will continue. It will take up to 60 minutes to complete. 

IT IS VERY IMPORTANT YOU DO NOT INTERRUPT THIS PROCESS AS IT MAY LEAVE YOUR MAC INOPERABLE"

iconsize="72"
dialogtimeout="210"

# log to the jamf log.
logto="/var/log/"
log="jamf.log"

#
# end of configurable settings
#

osxversion=$(sw_vers -productVersion | cut -f-2 -d.) # we don't need minor version

if [ ! -f "$cdialog" ]
then
	echo "FATAL: I can't find cocoadialog, stopping 'ere"
	exit 1
fi

# command line paramaters
mode="$4"
prereqreceipt="$5"
prereqpolicy="$(echo $6 | sed -e 's/ /\+/g')" # change out " " for +
option="$7"
spawned="$1" # used internally

if $selfsignedjsscert
then
	curlopts="-k"
else
	curlopts=""
fi

bootstrapagent="/Library/LaunchAgents/com.github.patchoo-bootstrap.plist"
jssgroupfile="/tmp/$name-jssgroups.tmp"

# set and read preferences
computername=$(scutil --get ComputerName)
jssurl=$(defaults read /Library/Preferences/com.jamfsoftware.jamf "jss_url" 2> /dev/null)

daystamp=$(($(date +%s) / 86400)) # days since 1-1-70


# create the data folder if it doesn't exist
[ ! -d "$datafolder" ] && mkdir -p "$datafolder"
[ ! -d "$pkgdatafolder" ] && mkdir -p "$pkgdatafolder"

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
patchootmp="/tmp/patchootmp-$$" # i need to find you during debug
mkdir "$patchootmp"
#patchootmp="$(mktemp -d -t patchoo)" 

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
		if [ "$(checkConsoleStatus)" == "userloggedin" ]
		then
			echo "$name: USERNOTIFY:: $title, $message"
			echo "$(date "+%a %b %d %H:%M:%S") $computername $name-$version $mode: USERNOTIFY: $title, $message" >> "$logto/$log"			
			[ "$title" == "" ] && title="Message"
			[ "$icon" == "" ] && icon="notice"
			"$cdialog" bubble --title "$title" --text "$message" --icon $icon --timeout $timeout &
		else
			echo "$(date "+%a %b %d %H:%M:%S") $computername $name-$version $mode: USERNOTIFY-NODISPLAY: $title, $message" >> "$logto/$log"
		fi
	else
		# if we are bootstrapping, we display over loginwindow fullscreen mode with the bootstrap helper... update the msg
		if $bootstrapmode	
		then
			echo "$message" > /tmp/patchoo-loginmessage.tmp
		fi
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
	"$cdialog" msgbox --title "$title" --icon "$icon"  --text "$title2" --informative-text "$text" --timeout "$dialogtimeout" --button1 "$button1" --button2 "$button2" --button3 "$button3" --icon-height "$iconsize" --icon-width "$iconsize" --width "500" --string-output
}

makeMessage()
{
	message="$message
	$1"
}

checkConsoleStatus()
{
	psauxout="$(ps aux)"
	userloggedin="$(who | grep console | awk '{print $1}')"
	consoleuser="$(ls -l /dev/console | awk '{print $3}')"
	screensaver="$(echo $psauxout | grep ScreenSaverEngine | grep -v grep)"

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
		# check for blocking apps
		for app in ${blockingapps[@]}
		do
			appcheck="$(echo $psauxout | grep "$app" | grep -v grep)"
			if [ "$appcheck" != "" ]
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
	if [ "$(ps aux | grep "$1" | grep -v grep)" == "" ]
	then
		echo "no"
	else
		echo "yes"
	fi
}

spawnScript()
{
	# we use this so we can execute from self service.app and call a logout with out breaking policy execution.
	# the script copies, then spawns itself 
	if [ "$spawned" != "--spawned" ]
	then
		tmpscript="/tmp/$name-$RANDOM.sh"
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
		# get pkgdata from the jss api
		curl $curlopts -s -u $apiuser:$apipass ${jssurl}JSSResource/packages/name/$(echo $pkgname | sed -e 's/ /\+/g') -X GET > "$pkgdatafolder/$pkgname.caspinfo.xml"
		# (error checking)
		pkgdescription=$(cat "$pkgdatafolder/$pkgname.caspinfo.xml" | xpath //package/info 2> /dev/null | sed 's/<info>//;s/<\/info>//')
		[ "$pkgdescription" == "<info />" ] && pkgdescription=$(echo "$pkgname" | sed 's/\(.*\)\..*/\1/') # if it's no pkginfo in jss, set pkgdescription to pkgname (less ext)
		echo "$pkgdescription" > "$pkgdatafolder/$pkgname.caspinfo"

		# if it's flagged as an OS Upgrade (using createOSXInstallPkg), add osupgrade flag
		[ "$option" == "--osupgrade" ] && touch "$pkgdatafolder/$pkgname.caspinfo.osupgrade"
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
				prereqpolicyid=$(curl $curlopts -s -u $apiuser:$apipass ${jssurl}JSSResource/policies/name/$prereqpolicy -X GET | xpath //policy/general/id 2> /dev/null | sed -e 's/<id>//;s/<\/id>//')
				# (error checking)
				# let's run the preq policy via id
				# this is how we chain incremental updates
				jamf policy -id $prereqpolicyid
			fi
		fi
	else
		secho "i couldn't find a new pkg in the waiting room. :("
	fi

}

checkASU()
{
	if $patchooasureleasemode
	then
		getGroupMembership
		setASUCatalogURL
	fi

	swupdateout="$patchootmp/swupdateout-$RANDOM.tmp"
	secho "checking for apple software updates..."
	softwareupdate -la > "$swupdateout"
	# check if there are any updates
	if [ "$(cat $swupdateout | grep "*")" != "" ]
	then
		# let's parse the updates
		# set IFS to cr
		OLDIFS="$IFS"
		IFS=$'\n'
		asupkgarray=( $(cat $swupdateout | grep "*" | cut -c6- ) )
		asudescriptarray=( $(cat $swupdateout | grep -A2 "*" | grep -v "*" | cut  -f1 -d, | cut -c2- | sed 's/[()]//g' ) )
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
		IFS=$OLDIFS

		# check for restart required
		if [ "$(cat $swupdateout | grep "\[restart\]")" != "" ]
		then
			touch "$pkgdatafolder/.restart-required"
		fi
	else
		secho "no updates found."
	fi
	rm $swupdateout
}

setASUCatalogURL()
{
	# in patchooasureleasemode mode patchoo takes care of re-writing client catalog urls so you can have dev/beta/prod catalogs based on jss group membership
	# you set your catalogURL / swupdate server as you usually do in Casper, and it will re-write OS and branch specific URLs based on the local CatalogURL.
	# it assumes that you have turned off updates via other mechanisms 
	currentswupdurl=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate CatalogURL 2> /dev/null)
	
	if [ "$currentswupdurl" != "" ]
	then
		asuserver="$(echo $currentswupdurl | cut -f-3 -d/)"
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
			*)
				secho "I can't do this osx version.. sadface."
				return
				;;
		esac
		secho "setting asu CatalogURL to $swupdateurl"
		defaults write /Library/Preferences/com.apple.SoftwareUpdate CatalogURL "$swupdateurl"
	else
		secho "no asu server set, using apple's..."
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
		echo -e "${casppriority}\t${casppkg}\t${casppkgdescrip}" >> $casppkginfo
		[ -f  "${infofile}.osupgrade" ] && touch "$pkgdatafolder/.os-upgrade"
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
			[ "$(echo $infofile | grep EFIUpdate)" != "" ] && touch "$pkgdatafolder/.fw-update"
			[ "$(echo $infofile | grep SMCUpdate)" != "" ] && touch "$pkgdatafolder/.fw-update"
			[ "$(echo $infofile | grep Firmware)" != "" ] && touch "$pkgdatafolder/.fw-update"			
			# set priorities for system and sec updates
			asupriority=1
			#  OSX supplemental for 10.8.5 broke the rules, not OSXUpd... this could catch other things too... hmm.
			[ "$(echo $infofile | grep OSX)" != "" ] && asupriority="98"
			# if it's a security or OSX update make it 99
			[ "$(echo $infofile | grep SecUpd)" != "" ] && asupriority="99"	
			[ "$(echo $infofile | grep OSXUpd)" != "" ] && asupriority="99"
			asupkg=$(basename "$infofile")	#get rid of path
			asupkg="${asupkg%\.*}"		#remove ext.
			asupkgdescrip=$(cat "$infofile")
			echo -e "${asupriority}\t${asupkg}\t${asupkgdescrip}" >> $asupkginfo
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
	jamf install $jamfinstallopts -package "$casppkg" -path "/Library/Application Support/JAMF/Waiting Room" -target /
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
				casptotal=$(cat $casppkginfo | wc -l)
				total=$(( $casptotal * 100 ))		 		
		 		while read line
		 		do
					casppkgdescrip=$(echo "$line" | cut -f3)
					installCasperPkg "$line" & # background the jamf install, we'll fudge a progressbar
					caspinstallpid=$!
					# we are fudging a progress bar, count up to 100, increase bar, until done, then 
					for (( perfectcount=1; perfectcount<=100; perfectcount++ ))
					do
						percent=$(( ( (perfectcount + currentpercent) * 100 ) / $total ))
						(( $percent == 100 )) && percent=99	# we don't want out progressbar to finish prematurely
						echo "$percent Installing $casppkgdescrip ..."
						kill -0 $caspinstallpid 2> /dev/null
						[ "$?" != "0" ] && break # if it's done, break
						sleep 1
					done
					wait $caspinstallpid # if we have run out progress bar, wait for pid to complete.
					currentpercent=$(( currentpercent + 100 )) # add another 100 for each completed install				
				done < "$casppkginfo"
				echo "100 Installation complete"
				sleep 1
				[ -f "$pkgdatafolder/.restart-required" ] && echo "100 Restart is required"
				sleep 1
			) | "$cdialog" progressbar --icon installer --float --title "Installing Software" --text "Starting Install..."  --icon-height "$iconsize" --icon-width "$iconsize" --width "500" --height "114"
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
				asutotal=$(cat $asupkginfo | wc -l)
				total=$(( $asutotal * 100 ))

				while read line
				do
					asupkg=$(echo "$line" | cut -f2)
					asupkgdescrip=$(echo "$line" | cut -f3)
					secho "softwareupdate is installing $asupkg ..."
					
					# spawn the update process, and direct output to tmpfile for parsing (we probably should use a named pipe here... future...)
					swupdcmd="softwareupdate -v -i $asupkg"
					swupdateout="$patchootmp/swupdateout-$RANDOM.tmp"
					softwareupdate -v -i "$asupkg" > $swupdateout &
					# wait for the software update to finish, parse output of softwareupdate
					while [ "$(checkProcess "$swupdcmd")" == "yes" ]
					do
						sleep 1
						# get percent to update progressbar
						percentout=$(cat $swupdateout | grep "Progress:" | tail -n1 | awk '{print $2}' | sed 's/\%//g') 
						percent=$(( ( (percentout + currentpercent) * 100 ) / $total ))
						echo "$percent Installing $asupkgdescrip ..."
					done
					currentpercent=$(( currentpercent + 100 )) # add another 100 for each completed install
					rm $swupdateout
				done < "$asupkginfo"
				echo "100 Installation complete"
				sleep 1
				[ -f "$pkgdatafolder/.restart-required" ] && echo "100 Restart is required"
				sleep 1
			) | "$cdialog" progressbar --icon installer --float --title "Installing Apple Software Updates" --text "Starting Install..."  --icon-height "$iconsize" --icon-width "$iconsize" --width "500" --height "114"
		fi
	fi

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

	# there are waiting updates ... make a message for the user prompt	
	secho "prompting user ..."
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
			answer=$(displayDialog "$message" "$msgtitlenewsoft" "$msgnewsoftware" "package" "Install and Restart..." "Install and Shutdown..." "Later")
			
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
				if [ "$(echo $consolestatus | grep BlockingApp)" != "" ]
				then
					blockremain=$(( $blockappthreshold - blockappcount ))
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
						secho "FORCING INSTALL!"
					else
						# prompt user with defer option
						makeMessage ""
						makeMessage "$msginstalllater"
						answer=$(displayDialog "$message" "$msgtitlenewsoft" "$msgnewsoftware" "package" "Logout and Install..." "Later ($deferremain remaining)")
						secho "deferral counter: $defercount, defer thresold: $deferthreshold"
					fi
				else
						# if we don't have deferals enabled
						makeMessage ""
						makeMessage "$msginstalllater"
						answer=$(displayDialog "$message" "$msgtitlenewsoft" "$msgnewsoftware" "package" "Logout and Install..." "Later")
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
			preInstallWarnings
			fauxLogout
			installSoftware
			logoutUser
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
	osascript -e "ignoring application responses" -e "tell application \"loginwindow\" to $(echo -e \\xc2\\xab)event aevtrlgo$(echo -e \\xc2\\xbb)" -e "end ignoring"
}

# fauxLogout - added to workaround cocoaDialog not running outside a user session on mavericks+ - https://github.com/patchoo/patchoo/issues/16 
#
# thanks to Jon Stovell - bits inspired and stolen from quit script - http://jon.stovell.info/
#
# it just loops through all user visible apps, quits them and then unloads the finder and dock. dodgy!
getAppList()
(
	applist=$(sudo -u $user osascript -e "tell application \"System Events\" to return displayed name of every application process whose (background only is false and displayed name is not \"Finder\")")
	echo $applist
)

quitAllApps()
(
	applist=$(getAppList)
	applistarray=$(echo $applist | sed -e 's/^/\"/' -e 's/$/\"/' -e 's/, /\" \"/g')
	eval set $applistarray
	for appname in "$@"
	do
		secho "trying to quit: $appname ..."
		sudo -u $user osascript -e "ignoring application responses" -e "tell application \"$appname\" to quit" -e "end ignoring"
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
		for (( c=1; c<=(( $waitforlogout / $tryquitevery )); c++ ))
		do
			quitAllApps
			sleep $tryquitevery
			#check if all apps are quit break if so, otherwise fire every $tryquitevery
			[ "$(getAppList)" == "" ] && break
		done
		if [ "$(getAppList)" != "" ]
		then
			# if we still haven't quit all Apps
			dialogtimeout=60
			secho "no fauxlogout in $waitforlogout seconds, prompting user and trying logout again..."
			displayDialog "Ensure you have saved your documents and quit any open applications. You can Force Quit applications that aren't responding by pressing CMD-SHIFT-ESC." "Logging out" "The Logout process has stalled" "caution" "Continue Logout"
			quitAllApps
		fi
	done
	sudo -u $user launchctl unload /System/Library/LaunchAgents/com.apple.Finder.plist
	sudo -u $user launchctl unload /System/Library/LaunchAgents/com.apple.Dock.plist
	secho "fauxlogout done!"
)


processLogout()
{
	if [ "$installsavail" == "Yes" ]
	then
		# if <10.9 we can use this can prompt outside a user session with cdialog
		case $osxversion in	
			10.5 | 10.6 | 10.7 | 10.8 )
				# check if there are updates and prompt
				# prompt user
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
			;;
			*)
				# currently cdialog doesn't support running outside user session for this os
				secho "there are updates, but I can't prompt at the moment."
			;;
		esac
	fi
	
	# process a restart or shutdown
	if [ -f /tmp/.patchoo-restart ] || [ -f /tmp/.patchoo-shutdown ]
	then
		# run on recon on reboot
		secho "flagged for a post boot recon"
		touch "$datafolder/.patchoo-recon-required"
	else
		# otherwise no restart required, we can do it in the background whilst user logs back in
		jamfRecon &
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
			jamf policy -trigger "${updatetrigger[$groupid]}"
		fi
	fi
	# once we've got run our group trigger, run the standard...
	secho "jamf is firing ${updatetrigger[0]} trigger ..."
	jamf policy -trigger "${updatetrigger[0]}"

}

getGroupMembership()
{
	groupid=0
	macaddress=$(networksetup -getmacaddress en0 | awk '{ print $3 }' | sed 's/:/./g')
	# jss group file, we cache this in a central location so we can minimise number of hits on the jss for an update session.
	if [ ! -f "$jssgroupfile" ]
	then
		secho "getting computer group membership ..."
		curl $curlopts -s -u $apiuser:$apipass ${jssurl}JSSResource/computers/macaddress/$macaddress | xpath //computer/groups_accounts/computer_group_memberships[1] 2> /dev/null | sed -e 's/<computer_group_memberships>//g;s/<\/computer_group_memberships>//g;s/<group>//g;s/<\/group>/\n/g' > "$jssgroupfile"
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
	secho "You will be notified if any installations are available" 4 "Checking for new software" "notice"
	jamfPolicyUpdate
	[ "$(defaults read "$prefs" InstallsAvail  2> /dev/null)" != "Yes" ] && displayDialog "There is no new software available at this time." "No New Software Available" "" "info" "Thanks anyway"
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

bootstrapUpdates()
{
	spawnScript
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
			reboot &
			return
		fi
		# we will either reboot and pickup again at loginwindow
		# or run another update and install loop
		jamfRecon
		jamfPolicyUpdate
		installsavail=$(defaults read "$prefs" InstallsAvail 2> /dev/null)
	done

	# no more updates stop boottrap
	secho "All updates installed, bootstrap complete!"
	sleep 8
	rm "$bootstrapagent"
	rm /Library/Scripts/patchoo.sh
	killall jamfHelper
}

bootstrapSetup()
{
# write out a launchagent to call bootstrap helper
cat > "$bootstrapagent" << EOF
<?xml version="1.0" encoding="UTF-8"?>
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
</plist>
EOF

	# set permissions for agent
	chown root:wheel "$bootstrapagent"
	chmod 644 "$bootstrapagent"
	# copy the script to local drive
	cp "$0" /Library/Scripts/patchoo.sh
	chown root:wheel /Library/Scripts/patchoo.sh
	chmod 770 /Library/Scripts/patchoo.sh
	# unset any loginwindow autologin
	defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser ""
	secho "bootstrap setup done, you need to restart"
}

bootstrapHelper()
{
	# patchoo bootstrap helper
	#
	jamf policy -trigger bootstrap
	# message for loginwindow
	echo "running a recon..." > /tmp/patchoo-loginmessage.tmp
	while [ -f "$bootstrapagent" ]	# whilst the agent exists, we are in bootstrap mode
	do
		newmessage="$(cat /tmp/patchoo-loginmessage.tmp)"
		if [ "$message" != "$newmessage" ]
		then
			message="$newmessage"
			displaymsg="$computername
			$msgbootstrap

			$(date "+%H:%M:%S"): $message"
			killall jamfHelper
			"$jamfhelper" -windowType fs -description "$displaymsg" -icon "/System/Library/CoreServices/Installer.app/Contents/Resources/Installer.icns" &
			sleep 2
		fi
	done
	rm /tmp/patchoo-loginmessage.tmp
}

jamfRecon()
{
	secho "jamf is running a recon..."
	if [ "$1" == "--feedback" ]
	then
		( jamf recon ) | "$cdialog" progressbar --icon sync --float --indeterminate --title "Casper Recon" --text "Updating computer inventory..."  --icon-height "$iconsize" --icon-width "$iconsize" --width "500" --height "114" 
	else
		jamf recon
	fi		
	# if there is flag, remove it
	[ -f "$datafolder/.patchoo-recon-required" ] && rm "$datafolder/.patchoo-recon-required"
	secho "recon finished"
}

cleanUp()
{
	rm -R "$patchootmp"
	[ -f "$jssgroupfile" ] && rm "$jssgroupfile" 	# cached group membership
	[ "$spawned" == "--spawned" ] && rm $0 	#if we are spawned, eat ourself.
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
		remindInstall # run on every120
	;;

	"--startup" )
		startup 	#run on startup, recon if we've just installed updates that required a reboot
	;;
	
	"--logout" )
		# this is triggered by the logout hook, we do out installs on logout
		processLogout
	;;

	"--patchoostart" )
		# this starts the patchoo update process, triggered by -trigger patchoo
		patchooStart
	;;

	"--bootstrap" )
		bootstrapUpdates
	;;

	"--bootstrapsetup" )
		bootstrapSetup
	;;

	"--bootstraphelper" )
		# used internally by launchagent for loginwindow session
		bootstrapHelper
	;;
	
	*)
		secho "malfunction. :/ - i don't know how to $mode"
	;;

esac

# tidy up any leftovers
cleanUp

exit 0
