junki
=====

https://github.com/munkiforjamf/junki


Junki somewhat emulates [munki](https://code.google.com/p/munki/) workflows and user experience for JAMF Software's [Casper Suite](http://www.jamfsoftware.com/products/casper-suite/).  

Casper is the **best** all round management platform for all things Apple, but the fact it started it's life a few years a go when all Mac admins were using image based deployment workflows has meant there is a gap in functionality when it comes to post deployment patching. You can deploy patches via policies, but after looking at current best practices with Casper, I wasn't really happy with any current solutions or implementations.  

Munki is the absolute, positiviely best way to deploy and *thin image* Macs. It does one thing, and it does it amazingly well. It can install software and ensure Macs are patched better than other system. Junki is munki inspired, and *hopefully* brings some of munki's greatness to Casper.

#### junki isn't just a script... ####
  
It's a patching and deployment methodology that;  

* allows munki style deployment groups (*dev / beta / production / etc*)
* will re-write your ASU catalogURL so the same deployment groups can be pointed at [NetSUS](https://jamfnation.jamfsoftware.com/viewProduct.html?id=180&view=info) / [reposado](https://github.com/wdas/reposado) branches.
* can chain incremental updaters (*eg. MS Office 2011 14.3.7, 14.3.8, 14.3.9*)
* leverages existing existing Casper frameworks and methods (triggers, policies, smart groups) 

From a user experience persective it;   

* provides a much needed Casper a GUI for software installation.
* unifies Casper and Apple Software Update installations.
* allows installations to be deferred, allows flexibiliy but maintaining compliance.
* ensures users are logged out during installations.
* integrates nicely with Self Service.

![User Prompt](https://raw.githubusercontent.com/munkiforjamf/junki/master/docs/images/prompt.png)

### DISCLAIMER: USE AT YOUR OWN RISK! ###

*The documentation is sparse, the code is sloppy, it shouldn't be written in bash, but it works!
I am not a coder, but I do think I have nailed the workflows and user experience. It probably
should be re-written in Python once I am more comfortable.*



Requirements
------------
* CocoaDialog 3.x
* JAMF Casper (developed & tested on 9.22)
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


