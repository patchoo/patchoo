#!/bin/bash

#
# sets Apple Software Update URL based on JSS network segment information.
# for some reason in Casper 9 the ability to do this was removed??
#
# but the Casper9 API now exposes network segments and softwareupdate servers (which it didn't before ?)
# 
# slow and kludgey in bash, xpath is SLOW... but it works. set up a r/o API user
#
# reposado mode is for non-apple software update servers (although it would work on them too) that don't do URL re-writes based on client OS
#
# more info lach@rehrehreh.com -=- USE AT YOUR OWN RISK!!

# read only api user please!
apiuser="apiuser"
apipass="apipass"

# reposado mode (netsus) will direct clients to os specific catalog urls, otherwise apple software update server is expected (that does re-writes)
# eg. if true, http://swupdate.domain:8088/content/catalogs/others/index-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog for a 10.8 client
# eg. if false, http://swupdate.domain:8088/index.sucatalog would be written to the catalogURL
reposadomode=true

# if you are using a self signed cert for you jss, tell curl to allow it.
selfsignedjsscert=true

#
# don't touch below.
#

ipToInt()
{
	# ip to int - thanks jjamroc https://gist.github.com/jjarmoc/1299906
	ip=${1}
	ipnum=0
	for (( i=0 ; i<4 ; ++i ))
		do
		((ipnum+=${ip%%.*}*$((256**$((3-${i}))))))
		ip=${ip#*.}
	done
	echo $ipnum 
} 

if ${selfsignedjsscert}
then
	curlopts="-k"
else
	curlopts=""
fi

jssurl=$(defaults read /Library/Preferences/com.jamfsoftware.jamf "jss_url")

# make tmp folder
tmpdir="/tmp/asucatalogset-$$" # i need to find you during debug
mkdir "${tmpdir}"
tmpnetsegout="${tmpdir}/jssnetsegs.xml"

osxversion=$(sw_vers -productVersion | cut -f-2 -d.) # we don't need minor version
myip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1) # this will get primary iface ip (in case of multiple ifaces)
myipint=$(ipToInt ${myip})

echo "my ip: ${myip}"

curl ${curlopts} -H "Accept: application/xml" -s -u "${apiuser}:${apipass}" ${jssurl}JSSResource/networksegments > "${tmpnetsegout}"

# get number of segments
netsegsize=$(xpath $tmpnetsegout "//network_segments/size/text()" 2> /dev/null)

echo "parsing ${netsegsize} network segments..." # xpath is slow as molasses but it gets the job done in bash, (i should keep learning python) - these is a better way of doing this i haven't though of
for (( i=1; i<=$netsegsize; i++ ))
do
	netsegid[$i]=$(xpath $tmpnetsegout "//network_segments/network_segment[$i]/id/text()" 2> /dev/null)
	netsegstartip[$i]=$(xpath $tmpnetsegout "//network_segments/network_segment[$i]/starting_address/text()" 2> /dev/null )
	netsegendip[$i]=$(xpath $tmpnetsegout "//network_segments/network_segment[$i]/ending_address/text()" 2> /dev/null )
done

foundseg=false

# find which segment we are in.
for (( i=1; i<=$netsegsize; i++ ))
do
	netsegstartint=$(ipToInt ${netsegstartip[$i]})
	netsegendint=$(ipToInt ${netsegendip[$i]})

	if (( ${netsegstartint} <= ${myipint} && ${myipint} <= ${netsegendint} ))
	then
		echo "found network seg: ${netsegstartip[$i]} < ${myip} < ${netsegendip[$i]}"
		foundseg=true
		break
	fi
done

if $foundseg
then
	echo "getting swupdate server..."
	mynetidx=$i
	curl ${curlopts} -H "Accept: application/xml" -s -u "${apiuser}:${apipass}" ${jssurl}JSSResource/networksegments/id/${netsegid[$mynetidx]} > "${tmpdir}/mynetseg.xml"
 	asuservername=$(xpath "${tmpdir}/mynetseg.xml" "//network_segment/swu_server/text()" 2> /dev/null)
 	curl ${curlopts} -H "Accept: application/xml" -s -u "${apiuser}:${apipass}" ${jssurl}JSSResource/softwareupdateservers/name/$(echo ${asuservername} | sed -e 's/ /\+/g') > "${tmpdir}/asuserver.xml"
 	asuserver=$(xpath "${tmpdir}/asuserver.xml" "//software_update_server/ip_address/text()" 2> /dev/null)
 	asuport=$(xpath "${tmpdir}/asuserver.xml" "//software_update_server/port/text()" 2> /dev/null)

	if ${reposadomode}
 	then
		case ${osxversion} in	
			10.5)
				swupdateurl="http://$asuserver:$asuport/content/catalogs/others/index-leopard.merged-1.sucatalog"
				;;
			10.6)
				swupdateurl="http://$asuserver:$asuport/content/catalogs/others/index-leopard-snowleopard.merged-1.sucatalog"
				;;
			10.7)
				swupdateurl="http://$asuserver:$asuport/content/catalogs/others/index-lion-snowleopard-leopard.merged-1.sucatalog"
				;;
			10.8)
				swupdateurl="http://$asuserver:$asuport/content/catalogs/others/index-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog"
				;;
			10.9)
				swupdateurl="http://$asuserver:$asuport/content/catalogs/others/index-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog"
				;;
			10.10)
				swupdateurl="http://$asuserver:$asuport/content/catalogs/others/index-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog"
				;;
			*)
				echo "I can't do this osx version.. sadface."
				;;
		esac
	else
		swupdateurl="http://${asuserver}:${asuport}/index.sucatalog"
	fi
	
	# write the new CatalogURL
	if [ "${swupdateurl}" != "" ]
	then
		echo "setting asu CatalogURL to ${swupdateurl}"
		defaults write /Library/Preferences/com.apple.SoftwareUpdate CatalogURL "${swupdateurl}"
	else
		echo "i couldn't set the CatalogURL, sorry bra.."
	fi
else
	echo "I couldn't match you to a network segment in the JSS.. sorry about that."
fi

rm -R "$tmpdir"
exit
