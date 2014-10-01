Setup Patchoo Deploy (script)
=============================

The following options must be set in the `0patcho.sh` script.

```
#
# patchooDeploy settings
#
pdusebuildea=true
pdusedepts=true
pdusebuildings=false

pdsetcomputername=true # prompt to set computername

# the name of your ext attribute to use as the patchooDeploy build identfier - a populated dropdown EA.
pdbuildea="patchoo Build"

# do you want to prompt the console user to set attributes post enrollment? (not possible post casper imaging)
pdpromptprovisioninfo=true

# this api user requires update/write access to computer records (somewhat risky putting in here - see docs) 
# leaving blank will prompt console user for a jss admin account during attribute set (as above)
pdapiadminname=""
pdapiadminpass=""

pddeployreceipt="/Library/Application Support/JAMF/Receipts/patchooDeploy" # this fake receipt internally, and to communicate back to the jss about different patchoo deploy states.

```

You can enable and disable the use of:

* Patchoo Build EA
* Departments
* Buildings

If true, patchoo Deploy will require these items are filled in order for deployment to start. If any of the required items are blank, patchoo Deploy will go in to the "holding pattern".

`pdsetcomputername=true`  will prompt and allow the console user to set the computername.

`pdbuildea="patchoo Build"` 

Is the name of the **dropdown** extension attribute that is used to scope and fire a custom trigger. Make sure you make the name of the ext attribute the same in the JSS.

`pdpromptprovisioninfo=true` is used if you want the console user that is enroling the Mac to be prompted. If false, there is no prompting and the Mac sets up deploy mode, restarts and will go into a holding pattern if provisioning information is incomplete. The may be preferable if the user that is enroling isn't trusted.

`
pdapiadminname=""  pdapiadminpass=""
`
Could be set to the same as your existing [api user](setup_jss_api_access.md)... but your would have to also grant write access to computer objects. This could enable a BYOD workflow that allows users to set their own software builds or other provisioning information. 

***WARNING*** :this will store credentials with ***WRITE*** access in an unencrypted format. Due to the way Casper executes scripts and the way patchoo works, at some stages this script is written to the computer is different locations. This is not recommended, but could be a potential workflow in some organisations.

If left blank, the console user is prompted for JSS credentials that have write access (eg. for an L1/L2 user that is provisioning new Macs).


