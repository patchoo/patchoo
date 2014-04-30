Install CocoaDialog
-------------------
junki relies on the EXCELLENT [CocoaDialog](http://mstratman.github.io/cocoadialog/). You'll want to download, pkg and deploy it to all of your clients.

If you don't know how to make a pkg by now, you probably won't have much luck with junki. It might be time to stop reading and jump on a [Casper training course](http://www.jamfsoftware.com/training/).

Create a policy to install CocoaDialog, and make it run on startup, login, recurring or every15, scope it to all clients an run once per computer. **junki won't do anything without it!**

Ensure you [update your path](configuring_junki.sh.md) in junki.sh so it can locate it the binary!
