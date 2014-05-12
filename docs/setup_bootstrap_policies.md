Setup Bootstrap Policies
------------------------

### [zzz-junkiBootstrapSetup](id:junkiBootstrapSetup)

junkiBootstrapSetup is used post a Casper Imaging, or anytime you'd like to bring a non-compliant client to parity with your current patch release cycles.

It calls `0junki.sh --bootstrapsetup` which copies junki.sh to the local disk, writes out a launchagent that runs at loginwindow and runs `junki.sh --bootstraphelper`. Bootstraphelper, locks the loginwindow, provides GUI feedback (via jamfhelper bin fullscreen) and then fires a bootstrap loop.


