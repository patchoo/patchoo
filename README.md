junki
=====

https://github.com/munkiforjamf/junki


Junki somewhat emulates [munki](https://code.google.com/p/munki/) workflows and user experience for JAMF Software's [Casper Suite](http://www.jamfsoftware.com/products/casper-suite/).  

**Casper** is the best all round management platform for all things Apple. It's incredibly powerful and the JSS has no competetion, but the fact it started it's life a few years a go when Mac admins were using image based deployment workflows has meant there is a gap in functionality when it comes to post deployment patching. You can deploy patches via different built in triggers and policies but  there is no built-in GUI for user interaction and the user experience isn't great.

**Munki** is the absolute, positiviely best way to deploy and *thin image* Macs. It does one thing, and it does it amazingly well. It provides a great GUI, unifies Apple and 3rd party software installs and allows installations to be deferred. It can install software and ensure Macs are patched better than other system. Junki is munki inspired, and *hopefully* brings some of munki's greatness to Casper.

A lot of people have built different solutions on JAMFnation, but I think junki is the best and most complete way to deploy and patch your Macs "in the wild". It provides a great workflow for admins and an excellent user experience.

### junki isn't just a script... ###
  
...it's a patching and deployment methodology that;  

* allows munki style deployment groups (*dev / beta / production / etc*)
* will help re-write your Apple Software Update catalogURL so these deployment groups can be pointed at [NetSUS](https://jamfnation.jamfsoftware.com/viewProduct.html?id=180&view=info) / [reposado](https://github.com/wdas/reposado) branches.
* can chain incremental updaters (*eg. MS Office 2011 14.3.7, 14.3.8, 14.3.9*)
* leverages existing existing Casper frameworks and methods (triggers, policies, smart groups) 

From a user experience persective it;   

* provides Casper a much needed a GUI for software installation.
* unifies Casper and Apple Software Update installations.
* allows installations to be deferred, allows flexibiliy but maintaining compliance.
* ensures users are logged out during installations.
* integrates nicely with Self Service.

![User Prompt](https://raw.githubusercontent.com/munkiforjamf/junki/master/docs/images/prompt.png)

### DISCLAIMER: USE AT YOUR OWN RISK! ###

*The documentation is sparse, the code isn't pretty and it shouldn't be written in bash but it works! I am not a professional programmer, but I do think I have nailed the workflows and user experience. It probably should be re-written in Python once I am more comfortable.*



Requirements
------------
* CocoaDialog 3.x
* JAMF Casper (developed & tested on 9.22)
* http enabled dist points / JDS (policy within policy)
* OSX (10.6-10.9)
* *A big bunch of Macs!*


Documentation
-------------
     
https://github.com/munkiforjamf/junki/blob/master/docs/_index.md 


Help out!
---------


If you want to help in anyway please reach out via email or jump onto GitHub.

If you find it useful and want to say thank you, link up on LinkedIn, tell me how and where you are using it, and write me a recommendation whilst you are there! http://au.linkedin.com/in/lachlanstewart  
  
#### Enjoy junki responsibly!####

Lachlan.


