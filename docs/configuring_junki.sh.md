Configuring junki.sh
--------------------


### Basic Path Configuration   
  
You will need to edit your 0junki.sh to suit your environment before you upload it into Casper Admin.   
   
   
`````
#
# start configurable settings
#

name="junki"
version="0.982"

# read only api user please!
apiuser="apiuser"
apipass="apipassword"

datafolder="/Library/Application Support/junki"
pkgdatafolder="$datafolder/pkgdata"
prefs="$datafolder/com.github.munkiforjamf.junki"
cdialog="/Applications/Utilities/cocoaDialog.app/Contents/MacOS/cocoaDialog"
jamfhelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

# if you are using a self signed cert for you jss, tell curl to allow it.
selfsignedjsscert=true

`````

* Ensure you set your api user name and password that you [setup](setup_jss_api_access.md) previously.

* You can leave the paths as default, but ensure that junki can find [CocoaDialog](install_cocoadialog.md) on the clients.

* Set selfsignedcert=true if you are using a self signed cert, or false if you have a trusted certificate on your JSS.

### Basic Mode Configuration

These settings control how junki handles defers and blocking apps (eg. we shouldn't show update notifications when users are potentially presenting in Keynote)  
  
**note**: this is needs to be improved upon - ideally we need to find if these apps are in fullscreen mode - todo

`````
# users can defer x update prompts
defermode=true
defaultdeferthresold="10"

# users running blocking apps will have x number of prompts delayed, ie will not run on prompt/remindto install until threshold is reached
blockingappmode=true
defaultblockappthreshold="2" # if missed at lunch, then 2x2 hours later... should prompt in afternoon?

# if these apps are running notifications will not be displayed, presentation apps ? 
blockingapps=( "PowerPoint.app" "Keynote.app" )

`````

* defermode=true - allows the user to defer installations 10 times (default) before the installation is forced.  
  **note**: Changing the defaultthreshold has no affect once the script is run once as it's written to the preference file on the client. This will allow you to set different threshold on clients. In order to change the deferthreshold to '5' on a client, run directly, or via policy:

``````
defaults write /Library/Application\ Support/junki/com.github.munkiforjamf.junki DeferThreshold -int 5
``````
* blockingappmode=true - enabled blockingappmode, the threshold will allow x number of prompts to be blocked before a prompt will come up. Due to the fact that blockingapp handling isn't idea, users that run blockingapps all the time can miss prompts indefinitely. The threshold addresses this until we can improve the blocking app check.
* blockingapps=( "array" ) - is a list of processes to check for. If found, no reminders or prompts will be displayed in order to mitigate cases where a prompt may be displayed during a presentation.

### Advanced Mode Configuration

Please see [junki advanced](advanced_junki_overview.md) mode for configuration of these modes and arrays. They handle software release groups and reposado release forks.

`````
# this order will correspond to the updatetriggers and asurelease catalogs
# eg. 	jssgroup[2]="junkiBeta"
#  		updatetrigger[2]="update-beta"
#		asureleasecatalog[2]="beta"
#
# index 0 is the production group and is assumed unless the client is a member of any other groups

jssgroup[0]="----PRODUCTION----"
jssgroup[1]="junkiDev"
jssgroup[2]="junkiBeta"
	
# these triggers are run based on group membership, index 0 is run after extra group.
junkiswreleasemode=true
updatetrigger[0]="update"
updatetrigger[1]="update-dev"
updatetrigger[2]="update-beta"

# if using reposado mode these will be appended to computer's SoftwareUpdate server catalogs as per reposado -- if not using reposado mode the computer's SwUpdate server will remain untouched.
# eg. http://swupdate.your.domain:8088/content/catalogs/others/index-leopard.merged-1${asureleasecatalogs[i]}.sucatalog
junkireposadomode=true
asureleasecatalog[0]="prod"
asureleasecatalog[1]="dev"
asureleasecatalog[2]="beta"


`````

###GUI and Feedback Configuration

You can change a lot of the prompts to suit your environment, or add trust to the prompts by adding your organisation name to the *msgnewsoftware* varliable, eg `msgnewsoftware="YourCompany has made the following new software available"`

You can changes the logfile, by default junki logs into the */var/log/jamf.log*.

`````
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

`````

