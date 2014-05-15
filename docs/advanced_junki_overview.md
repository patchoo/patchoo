Advanced junki Overview
-----------------------

*junki advanced mode* is the collective term for the *junki sw release mode* and *junki asu release mode*. They aren't completely dependant one each other. If you aren't using [NetSUS](https://jamfnation.jamfsoftware.com/viewProduct.html?id=180&view=info) / [reposado](https://github.com/wdas/reposado) and forking Apple updates into release groups you can disable `junkiasurelasemode`. However, I certainly recommend you do look into it. [margarita](https://github.com/jessepeterson/margarita) is a great front end for reposado and it makes it super easy to fork update groups.



During the junkiPreUpdate policy, the JSS is queried, and should the Mac fall any of the sw release groups, the corresponding trigger will be executed.

eg.  
 
mac is a member of `junkiDev`, the update session goes like this.

* jamf policy -trigger update-dev
	* dev updates are cached 	
* jamf policy -trigger update
	* junkiCheckASU caches dev Apple Updates.
	* production updates are cached
	* user is prompted to install or defer
* end
 
*Macs that aren't in any of the special groups are consider production Macs and only run the `update` trigger.*
