Setup Extension Attributes
--------------------------
There are two main extension attributes patchoo needs.

* [patchoo Installs](../extattributes/patchoo Installs.xml)
	* *String* - patchoo installations are available (cached)
		* Yes 		
		* No 
		* n/a

* [patchoo Defer Count](../extattributes/patchoo Defer Count.xml) - *optional*
	* *Int* - patchoo defer counter (number of times a user has deferred install)
	
	
[Smart Groups](setup_smart_groups.md) as scoped from the results of these extension attributes. eg. The [reminder and self service Install New Software policy](setup_core_policies.md) is scoped to Macs that have patchoo Installs available, on the every120 [trigger](install_triggers.md).

You can import these directly into the JSS from the xml files, or copy and paste from the txt files provided.
