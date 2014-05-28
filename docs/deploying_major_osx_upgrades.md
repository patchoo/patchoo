Deploying Major OSX Upgrades
----------------------------

Deploying major OSX Upgrades build with the excellent [createOSXInstallPkg](https://code.google.com/p/munki/downloads/list) is identical to deploying any other pkg.

**IMPORTANT:** *Ensure that when you upload the pkg into Casper Admin, you set the "requires reboot" pkg metadata. This is read from the JSS by patchoo and will be required to complete the OSX Upgrade!*

### Create a deployment Smart Group

Scope your smart group (it's probably a good idea also do hardware compatibility checks in this scope - for simplicity's sake, we will ignore that for this exmaple).

As you did before, make sure that it hasn't been cached to prevent it repeatedly caching.

![smart group 10.9](images/smart_group_10.9.png)

### Create a policy

I will skip over the general tab, as it's identical to the [standalone installers](deploying_standalone_Installers.md). When you are configuring the script section it should look like this.

* Script: `0patchoo.sh`
* Priority: `after` 
* Mode (1st param): `--cache`
* prereq. receipt (opt. --cache): `''`
* prereq. policy (opt. --cache): `''`
* (opt. --osupgrade): `--osupgrade`
* pkg descript: `OSX 10.9 Mavericks Upgade`
* pkg filename: `OSXInstall10.9.pkg`

***IMPORTANT:***  *as of the time of writing, Casper 9.x has a bug (D-005830) with passing script parameters (empty parameters will bump their order). Even we shouldn't need to fill parameter 2 & 3, put in 2x single quotes to prevent these parameters from being empty*

![10.9 script](images/policy_10.9_script.png)

  
  
`--osupgrade` does two things:  

1. It present user warnings about the OSX Upgrade (connect to AC power, it could take over an hour etc).
2. It prevents Apple Updates from being installed during the install process, and flushes the Software Update Cache (/Library/Updates/).


### User Interface for OSX Upgrades


![osx warning prompt](images/warning_osx_prompt.png)

If the user chooses to install, there will be a second warning (for them to ignore :) ). There are similar warnings if **firmware updates** are detected as part of the Apple Software Update installations.

![osx warning 2](images/warning_osx_2.png)


___

That's it! Thanks to the magic of createOSXInstallPkg, patchoo will install the OSX upgrade pkg and reboot the Mac. The unattended OSX Installation will take over and upgrade your Macs. The Mac will reboot and the patchStartup policy will recon your Mac.
