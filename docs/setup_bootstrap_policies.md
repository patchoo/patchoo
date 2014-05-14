Setup Bootstrap Policies
------------------------

### zzz-junkiBootstrapSetup

junkiBootstrapSetup is used post a Casper Imaging, or anytime you'd like to bring a non-compliant client to parity with your current patch release cycles.

It calls `0junki.sh --bootstrapsetup` which copies junki.sh to the local disk, writes out a launchagent that runs at loginwindow and runs `junki.sh --bootstraphelper`. Bootstraphelper, locks the loginwindow, provides GUI feedback (via jamfhelper bin fullscreen) and then fires a bootstrap loop.

![bootstrapsetup policy general](images/policy_bootstrapsetup_general.png)

![bootstrap policy script](images/policy_bootstrapsetup_script.png)

Scope: `allClients`

___

### zzz-junkiBootstrap

junkiBootstrap actually drives the bootstrap process. It is called by the local `junki.sh --bootstraphelper` (the process responsible for locking the loginwindown and providing local GUI).

![bootstrap policy general](images/policy_bootstrap_general.png)

![bootstrap policy script](images/policy_bootstrap_script.png)

Scope: `allClients`

___
