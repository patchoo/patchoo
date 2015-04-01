Setup Categories
----------------

Creating categories within your JSS will help organise your policies, and if using [patchoo Advanced mode](advanced_patchoo_overview.md) it will give you a good visual representation of which package deployments are in dev, beta, and production.

If you are not using [patchooSWReleaseMode](advanced_patchoo_overview.md), you can skip creation of the -beta, -dev categories.

As with the 0patchoo.sh script, naming your categories with preceeding 0's will mean they sort alphabetically.

The suggested categories are:

* `0patchoo` - for software updates in production
* `0patchoo-beta` - for software updates in beta
* `0patchoo-dev` - for software updates in dev/testing
* `0patchoo-z-core` - for the patchoo's core policies that drive the process

If you aren't using [patchoo Advanced mode](advanced_patchoo_overview.md) you can skip setting up the dev and beta categories.

Click:

* Settings
* Global Management
* Categories
* New 

Create your categories. To give you an idea of how your categories will be presented within the JSS when in use, here's an example screenshot.

![Policies](images/policies.png)

