Install Triggers
----------------
junki requires two additional triggers to work as documented. Depending on whether or not you use [advanced junki mode](advanced_junki_overview.md), you will use the following.


### Basic ###

* update	- chains update policies for production installations
* every120	- fires reminder bubbles, or reminder prompts


### Advanced Mode ###
* preupdate	- checks [group membership](setup_computer_deployment_groups.md) and fires software deployment trigger *(eg. update-dev, update-beta)* it then fires the update trigger
* every120 - as above

You can modify the triggers to suit your environment, but by default the update/preupdate run at midday, randomised by 1800 seconds. Every120 (as implied) runs every two hours to balance gentle reminders, with annoyance :)

There are packages you can deploy on all clients via policy, or modify and package yourself.

**Install only the preudpate or the update pkg ** both contain the every120 trigger, but if using [advanced junki mode](advanced_junki_overview.md) only install the preupdate trigger.






