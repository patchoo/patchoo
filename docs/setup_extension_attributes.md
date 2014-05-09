Setup Extension Attributes
--------------------------
There are two main extension attributes junki needs.

* [junki Installs](../extattributes/junki Installs.xml)
	* *String* - junki installations are available (cached)
		* Yes 		
		* No 
		* n/a

* [junki Defer Count](../extattributes/junki Defer Count.xml) - *optional*
	* *Int* - junki defer counter (number of times a user has deferred install)
	
	
[Smart Groups](setup_smart_groups.md) as scoped from the results of these extension attributes. eg. The [reminder policy](setup_core_policies.md) is scoped to Macs that have junki Installs available, on the every120 [trigger](install_triggers.md).

You can import these directly into the JSS from the xml files provided, or copy and paste from below.


### junki Installs ###

```
#!/bin/bash
prefs="/Library/Application Support/junki/com.github.munkiforjamf.junki"
key="InstallsAvail"

result=$(defaults read "$prefs" "$key")

if [ "$?" == "0" ]
then
    echo "<result>$result</result>"
else
    echo "<result>n/a</result>"
fi

```

### junki DeferCount ###
```
#!/bin/bash
prefs="/Library/Application Support/junki/com.github.munkiforjamf.junki"
key="DeferCount"

result=$(defaults read "$prefs" "$key")

if [ "$?" == "0" ]
then
    echo "<result>$result</result>"
else
    echo "<result>0</result>"
fi

```


