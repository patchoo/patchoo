Install Triggers
----------------
patchoo requires two additional triggers to work as documented. Depending on whether or not you use [advanced patchoo mode](advanced_patchoo_overview.md), you will use the following.

### Basic ###

* update	- chains update policies for production installations
* every120	- fires reminder bubbles, or reminder prompts


### Advanced Mode ###
* preupdate	- checks [group membership](setup_computer_deployment_groups.md) and fires software deployment trigger *(eg. update-dev, update-beta)* it then fires the update trigger
* every120 - as above

You can modify the triggers to suit your environment, but by default the update/preupdate run at midday, randomised by 1800 seconds. Every120 (as implied) runs every two hours to balance gentle reminders, with annoyance :)

This triggers are [here](triggers), you can use the ready made packages and deploy on all clients via policy, or modify and package them yourself.

**If using the ready made packages, use ONLY the preudpate or the update pkg**. Both contain the every120 trigger. If using [advanced patchoo mode](advanced_patchoo_overview.md) ***recommended*** only install the preupdate trigger, as the preupdate policy will fire update triggers.






