Bootstrap Overview
------------------

*** This documentation needs to be updated, this describes the update loop in a bootstrap, now with patchoo Deploy this process is run post deploy --- bootstrap is the term given to both the deploy and update loop process ***

Bootstrap mode is optional, but can be used to compensate to for version drift in your Casper Imaging configurations. It's designed to be run post first reboot after a Casper Imaging session.

It basically:

* Locks the loginwindow and provides UI feedback via jamfhelper fullscreen.
	* Runs a recon (to ensure Macs are in the correct deployment groups)
	* Runs patchoo -trigger preupdate
	* update / cache process runs (3rd party and apple updates cached)
	* all updates are installed
		* if reboot required, Mac is rebooted.. loop back to start
	* Loop back to start
	
	* no updates?
	* break
	* unlock loginwindow
	
Fully patched Mac!

You need to create a couple of policies to drive bootstrap and upload a script to add to your computer configurations in Casper Imaging. Go ahead!
