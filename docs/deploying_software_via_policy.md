Deploying Software via Casper Policies
======================================

A key feature of patchoo (like munki) is that it unifies the deployment of both Apple and 3rd party software installations and patches. Not having different notifications and dialogs for software patches is better from a user experience perspective, and it builds trust that software deployed is vetted by IT.

Deploying software via patchoo is probably quite similar to the way you've been deploying 3rd party patches without patchoo. You just add in a script, sprinkle with some metadata, and utilise a workflow around testing and beta groups.

This section will explain the workflow. It's more involved, as Apple aren't providing you with packages, and a logic around what should be installed.

### Upload your pkg into Casper Admin

If you aren't using AutoPKG, I suggest you start. It does all the heavy lifting and can automate pkg creation.

I do suggest you follow AutoPKG's naming convention for your packages.

AppName-xxx.pkg

When you start [deploying chained incremental patches](deploying_chained_incremental_patches.md), it's important that you are following a good naming convention. It will make you life much easier.


