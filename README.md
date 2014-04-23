junki
=====
munki for jamf - a.k.a. junki

https://github.com/munkiforjamf/junki


Junki somewhat emulates munki workflows and user experience for JAMF's Casper.

It does many things, it isn't just a script, it's a patching and deployment system / workflow,
allowing munki style deployment groups (dev/beta/production). It can re-write your ASU catalogURL
to allow the same deployment groups to match up with reposado / NetSUS branches.

From a user experience persective, it gives Casper a GUI for patch installation. It unifies
Casper Pkg and Apple Software Update instllations. It allows installations to be deferred and
integrates with Self Service.

The documentation is sparse, the code is sloppy, it shouldn't be written in bash, but it works!
I am not a coder, but I do think I have nailed the workflows and user experience. It probably
should be re-written in Python once I am more comfortable with it.

Requirements
------------
CocoaDialog
JAMF Casper (tested on v 9.22)


If you want to help in anyway please reach out via email or jump onto GitHub.

If you like it and want to say thanks, link up on LinkedIn and write me a recommendation.
(It might help me a get a raise)  - http://au.linkedin.com/in/lachlanstewart  

Enjoy junki responsibly!

Lachlan.

#################################
DISCLAIMER: USE AT YOUR OWN RISK!
#################################
