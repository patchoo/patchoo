Setup JSS API access
--------------------

The patchoo script requires read-only access to the JSS API in order to be able to perform some tasks. It reads package, group, network segement and software update information directly from the API.

###Setup a read-only user in Casper admin like this

#####Click
1. Gear icon
2. System Settings
3. JSS User Accounts and Groups
4. New
5. Create Standard Account
6. Account Tab
	* Username: `apiuser`
	* Privilege Set: `Custom`
	* Full Name: `apiuser` (You could elect to add text to indicate it's used for patchoo)
	* Email: *blank*
	* Password: *a strong password* - try [here](https://www.random.org/passwords/?num=1&len=24&format=html&rnd=new)
	![API User](images/apiuser.png)
	
7. Privleges Tab, JSS Objects
	* All Read-Only (check all or)
		* Computers
		* Network Segments
		* Packages
		* Policies
		* Smart Computer Groups
		* Software Update Servers
		* Static Computer Groups
		
	![API Priv](images/apipriv.png)
	
8. Done!
