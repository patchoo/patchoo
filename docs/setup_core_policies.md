Setup Core Policies
-------------------
The following policies are the core of junki. They drive the caching, Apple Software Update, installation, logout, user prompts and installation reminders.

It's recommended that you create a [category](setup_categories.md) to house them within your JSS.


### 000-junkiPreUpdate
*optional for [junki advanced mode](advanced_junki_overview.md)*  

**trigger:** preudpate

If using [junki advanced mode](advanced_junki_overview.md) you can utilise the preudpate policy, fired by the [preudpate trigger](install_triggers.md). By using a preupdate policy, you can enforce limitations (network segments, time of day etc) so updates are not triggers on certain WAN or VPN connections.

The preupdate policy queries the [JSS via the api](setup_jss_api_access.md) and checks if the client is a member of the any of the [deployment groups](setup_computer_deployment_groups.md) (*dev / beta / production / etc*). If found it fires the relevant trigger (*eg. update-beta*) before firing the default *update* trigger.

Using this method allows us to allocate different software installations based on JSS group membership. This is great for a *dev / beta / production* similar to munki's catalogs.

