Setup Computer Deployment Groups
--------------------------------

### junki.sh Configuration

The following codeblock configures the groups that you will be using in the JSS. You can change these at will, or add them. They must correspond with the updatetriggers and asureleasecatalogs in the the next arrays.

```
# this order will correspond to the updatetriggers and asurelease catalogs
# eg. 	jssgroup[2]="junkiBeta"
#  		updatetrigger[2]="update-beta"
#		asureleasecatalog[2]="beta"
#
# index 0 is the production group and is assumed unless the client is a member of any other groups

jssgroup[0]="----PRODUCTION----"
jssgroup[1]="junkiDev"
jssgroup[2]="junkiBeta"

```

### JSS Configuration

Create either static or smart groups corresponding to the names above. I use static groups and find some power users, or more daring staff that would like to beta test updates, but you could also use certain criteria in a smart group to scope your beta releases too.

Like munki's catalogs, it's an open configuration and could be used other uses too. As of writing, computers should only be a member of one group, but this will likely change.


*Macs that aren't in any of the special groups are consider production Macs and only run the `update` trigger.*