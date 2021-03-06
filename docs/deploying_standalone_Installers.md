Deploying Standalone or Drag and Drop Installers
------------------------------------------------

Now you have a [smart group](scoping_software_deployment_smart_groups.md) for this application update, we'll go on to how to setup a policy to cache the update.

Drag and drop installation or standalone/combo updaters are easy, as they don't require a preexisting version or update be installed. Fear not though [patchoo can handle incrementals too!](deploying_chained_incremental_patches.md)

We'll follow on from our VLC example in the smart group.

In this example we will assume you are using patchoo advanced, and software deployment groups. This patch will first of all be deployed to our dev / testing group.

If you were deploying to production computers, you would just ensure that it's linked to the `update` trigger. It is recommended that you look at using groups though as it will


Create a new policy as follows:

#### General tab

* Name: `updateVLC-2.1.4`
* Enabled: `true`
* Category: `0-patchoo-dev` or `0-patchoo` if you aren't using [software deployent groups](setup_computer_deployment_groups.md)
* Trigger: `update-dev` or `update`  if you aren't using [software deployent groups](setup_computer_deployment_groups.md)
* Execution: `ongoing`

![vlc general](images/policy_vlc_general.png)

#### Package Tab

* Pkg: `VLC-2.1.4.pkg`
* Action: `Cache`  ***IMPORTANT***
* FUT / FEU (up to you!)

It's important that the package is **cached**. patchoo will notify the user and perform the installation later.

![vlc pkg](images/policy_vlc_pkg.png)

#### Script tab

* Script: `0patchoo.sh`
* Priority: `after` ***IMPORTANT***
* Mode (1st param): `--cache`

*If you used version prior to 0.99 you will notice that this is simplified*

![vlc script](images/policy_vlc_script.png)

#### Scope / Targets tab

* Computer Group: `updateVLC-2.1.4`

This is the group you created in the [previous secton](scoping_software_deployment_smart_groups.md)

![vlc scope](images/policy_vlc_scope.png)

___

   
Overview of patchoo ---cache Policy Execution
-------------------------------------------
   
   
![vlc cache ovewiew](images/overview_patchoo_cache_policy.png)
