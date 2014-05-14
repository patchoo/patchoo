Scoping Software Deployment Smart Groups
========================================

Step 1 - Create a smart group
-----------------------------

If you've used Casper for a while you will be familiar with smart groups. By querying our JSS data, we can create a group of computers that we will scope and cache our packages too.

In this example we will deploy an update for VLC.

I recommend following the following naming convention for smart groups.

updateAppName-xxx

Name: `updateVLC-2.1.4`
Criteria  

AND

* Cached Packages **does not have** `VLC-2.1.4.pkg`
* Packages Installed By Casper **does not have** `VLC-2.1.4.pkg`
* Application Title **has** `VLC`
* Application Version **is not** `2.1.4`

Breaking this down:

* Any computer that has already cached `VLC-2.1.4.pkg` will not be a member of the group, hence the pkg will only cache once.
* Any computer that has already had Casper install `VLC-2.1.4.pkg` will not be a member of the group, so the installation should only run once.
* Any computer that has VLC, AND it is NOT version 2.1.4 will land in this group, on the junki update run, the pkg will cache for installation.

It's recommended that you put the application version at the end of the smart group, as you will see from the example in the following chapters.

![vlc smart group](images/smart_group_vlc.png)



	