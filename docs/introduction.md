Introduction
------------
#### What is junki?  

junki (a.k.a. munki-fo-jamf) is a script and patching system / methodology for JAMF’s Casper suite. It borrows many ideas from the excellent munki, hence the homage.  

Casper is the most complete and refined management platform for OSX and Apple devices. It’s ultra powerful and open-ended, the JSS is outstanding as is Self Service.app. However, it’s software deployment and patch management has some serious gaps. Casper Imaging is nice, but the general consensus amongst OSX admins is to move away image centric workflows.   

junki aims to work within Casper’s frameworks and augment the patch delivery. I suggest that you continue using Casper Imaging for initial software deployment (in fact I think Casper Imaging should be renamed to Casper Deploy - just don’t erase the disk in your workflow!), and then junki can help out in for post deployment patching.
junki can also leverage NetSUS / Reposado for dev / beta and production Apple Software catalogs (which I recommend doing if you aren’t!).   

#### What does junki do that OOTB Casper doesn’t?

* It provides a unified UI for Apple Software Updates and Casper deployed software.
* Non-administrator users can deploy software.
* It’s uses the already familiar Self Service.app
* It can chain incremental software update installers (eg. Office 14.0.1, 14.0.2)
* It allows flexibility around installation, allowing users to defer installation until a more convenient time.
* It can be used with different testing group levels (eg. dev/beta/production) based on JSS groups for dev, beta and production clients.
* It can use the same groups to leverage NetSUS / Reposado catalogs for dev, beta and production Apple patches.
