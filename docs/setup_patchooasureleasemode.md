Setup patchooASUReleaseMode
-------------------------

patchooASUReleaseMode allows patchoo.sh to re-write your Apple Software Update CatalogURL dynamically that corresponds to JSS computer group membership. This allows you to point clients at CatalogURLs for different stages of release. It also handles writing the OSX version specific catalog.

If you aren't using reposado or NetSUS forks, you can just [extras/asucatalogset.sh](extras/asucatalogset.sh) to set your CatalogURL. When patchooASUReleaseMode is disabled, `patchoo.sh --checkasu` will leave the CatalogURL unchanged.
	 

### patchoo.sh Configuration

The following codeblock configures the triggers that corespond to the [deployment groups](setup_computer_deployment_groups.md) you setup. The array index must match the group you'd like have appended CatalogURL.

eg. a Mac running OSX 10.8, that is a member of patchooBeta would have the following CatalogURL written before checking for Apple Updates.

`http://swupdate.domain:8088/content/catalogs/others/index-mountainlion-lion-snowleopard-leopard.merged-1_beta.sucatalog`


```
# if using patchoo asu release mode these will be appended to computer's SoftwareUpdate server catalogs as per reposado forks -- if not using asu release mode the computer's SwUpdate server will remain untouched.
# eg. http://swupdate.your.domain:8088/content/catalogs/others/index-leopard.merged-1${asureleasecatalogs[i]}.sucatalog
patchooasureleasemode=true
asureleasecatalog[0]="prod"
asureleasecatalog[1]="dev"
asureleasecatalog[2]="beta"

```
