Install Triggers
----------------
patchoo requires two additional triggers to work as documented. 



* `patchoo` - should be linked to the [patchooStart](setup_core_policies.md) policy.
* `every120`	- should be linked to the [patchooUpdateRemindPrompt](setup_core_policies.md) policy.

You can modify the triggers to suit your environment, but by default the `patchoo` trigger runs at midday, randomised by 1800 seconds. Every120 (as implied) runs every two hours to balance gentle reminders, with annoyance :)

This triggers are [here](http://github.com/patchoo/patchoo/tree/master/triggers), you can use the ready made packages and deploy on all clients via policy, or modify and package them yourself.




