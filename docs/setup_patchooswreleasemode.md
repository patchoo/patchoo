Setup patchooSWReleaseMode
------------------------

patchooswreleasemode is a method to fire a trigger, that corresponds to JSS computer group membership. In the screenshot below you can see different update policies linked to different triggers.

![policy overview](images/policy_office_overview.png)
	 

### patchoo.sh Configuration

The following codeblock configures the triggers that corespond to the [deployment groups](setup_computer_deployment_groups.md) you setup. The array index must match the group you'd like to assign the trigger to.


```
# these triggers are run based on group membership, index 0 is run after extra group.
patchooswreleasemode=true
updatetrigger[0]="update"
updatetrigger[1]="update-dev"
updatetrigger[2]="update-beta"

```
