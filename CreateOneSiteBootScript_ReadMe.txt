** The information below is also located in the following Adaptiva Support article:
https://support.adaptiva.com/hc/en-us/articles/115001545992
**

DESCRIPTION:
The Adaptiva CreateOneSiteBoot PowerShell script will assist in creating a boot image which includes the Adaptiva OneSite OneSiteDownloader utility.

It will handle three scenarios:
-Can be run to create a brand new boot image based off of out-of-the-box Microsoft ConfigMgr boot WIMs. 
-Can be run to create a brand new boot image based off of your current boot WIM.
-Can be run to simply mount your current boot WIM, add an updated OneSiteDownloader file, then unmount.

File Name:
CreateOneSiteBoot.ps1

Mandatory Parameters:
-bootImgArch
-OneSiteSource

Optional Parameters:
-BootImageID
-SiteServer
-DP
-MP
-MediaMode
-YearstoExpire
-Password
-CertPath
-CertPassword
-UserDeviceAffinity
-UpdateBootImagePath

Optional Switches:
-UnknownSupport
-CMDSupport


EXAMPLES:
Example 1: To create a new x64 OneSite boot image with the self-signed certificate set to expire after 5 years, allowing command-line support, unknown computer support, and Media mode is set to sitebased (recommended when a single primary site exists).
CreateOneSiteBoot.ps1 -bootImgArch x64 -OneSiteSource "C:\AdaptivaOneSiteSource" -SiteServer FQDNofSiteServer.domain.com -DP FQDNofDP.domain.com -MP FQDNofMP.domain.com -MediaMode SiteBased -YearstoExpire 5 -CMDSupport -UnknownSupport

Example 2: To create a new x64 OneSite boot image based off of your current boot image with the self-signed certificate set to expire after 5 years, allowing command-line support, unknown computer support, and Media mode is set to sitebased (recommended when a single primary site exists).
CreateOneSiteBoot.ps1 -bootImgArch x64 -OneSiteSource "C:\AdaptivaOneSiteSource" -BootImageID "PackageIDofCurrentBootImage" -SiteServer FQDNofSiteServer.domain.com -DP FQDNofDP.domain.com -MP FQDNofMP.domain.com -MediaMode SiteBased -YearstoExpire 5 -CMDSupport -UnknownSupport

Example 3: To simply update your current OneSite boot image with a newer version of OneSiteDownloader. This option will simply mount your current boot image, copy the new version of OneSiteDownloader, unmount the image, and update distribution points.
CreateOneSiteBoot.ps1 -bootImgArch x64 -OneSiteSource "C:\AdaptivaOneSiteSource" -UpdateBootImagePath "C:\BootImage\BootImage.WIM" -BootImageID "PRI0001A"

Example 4: To create a new x64 OneSite boot image with password protection enabled, command support enabled, unknown computer support enabled, and a 5 year expiration for the self-signed certificate, and the site server, DP, and MP are on the same server.
CreateOneSiteBoot.ps1 -bootImgArch x64 -OneSiteSource "C:\AdaptivaOneSiteSource" -Password 'secretpassword' -CMDSupport -UnknownSupport -YearstoExpire 5

Example 5: To create a x86 OneSite boot image with PKI certificate and unknown computer support enabled.
CreateOneSiteBoot.ps1 -bootImgArch x86 -OneSiteSource "C:\AdaptivaOneSiteSource" -CertPath C:\Certificate.pfx -CertPassword 'certificatepassword' -UnknownSupport

LIMITATIONS:
-This script must be run on the Primary site server in order to access specific files and folders.
-This script must be run on Windows Server 2012 or later.
-This script will store the customized WIM file which functions as the boot image source in the following location: \\<SiteServer>\SMS_<SiteCode>\OSD\boot\OneSiteBoot\<architecture>\OneSiteBoot<architecture>.wim unless the -UpdateBootImagePath switch is used.
-Additional configuration outside of the available parameters such as drivers, or pre-start commands must be done separately.
-If specifying a password for certificate or the boot image, use single quotes in the command line in the case where special characters are used. Example: -CertPassword 'secretpassword'

MANDATORY PARAMETERS
-bootImgArch
The  desired OS architecture for the boot image.
The options are either "x64" or "x86".

-OneSiteSource
The path to the folder containing OneSiteDownloader.exe or OneSiteDownloader64.exe.

OPTIONAL PARAMETERS
-BootImageID
The package ID of the boot image in which the new boot image will be based. A copy of the boot image will be made, and the boot image referenced in this parameter will not be altered.

-SiteServer
FQDN of the ConfigMgr Primary Site Server. If not specified, the name of the computer the script is being run on will be used.

-DP
FQDN of the desired Distribution Point that the boot image will be copied to during script processing. If not specified, the value of the -SiteServer parameter will be used.

-MP
FQDN of the desired Management Point that the script references for script processing. If not specified, the value of -SiteServer will be used.

-MediaMode
"Dynamic" or "SiteBased" If not specified, the default is Dynamic. In the case where there is a single Primary Site, SiteBased should be used.

-YearstoExpire
The number of years in which the self-signed certificate will expire. Default: 2 years

-Password
The password associated with the boot image. If not specified, no password will be used. Does not apply if the -CertPath parameter is used.

-UserDeviceAffinity
AdministratorApproval or AutoApproval or DoNotAllow. If not specified, the value DoNotAllow will be used.

-UpdateBootImagePath
This parameter should contain the full fixed path to the boot image (.WIM) file. It will be mounted,  a new copy of OneSiteDownloader will be copied, the image will be unmounted, and the DP will be updated. Must be used with the -BootImageID parameter.
Note: When specifying the path to the boot image's WIM file, use the WIM file without the package ID in the file name. 

-CertPath
The full path to the exported PKI certificate (.pfx file) to be used for the boot image. Must be used with the -CertPassword parameter.

-CertPassword
The password used for the exported PKI certificate. Must be used with the -CertPath parameter.

OPTIONAL SWITCHES
-UnknownSupport
If specified, unknown computer support will be enabled.

-CMDSupport
If specified, command prompt support will be enabled.

TASK SEQUENCE VARIABLE and LOGGING:
When loaded in Windows PE, OneSiteDownloader.exe will be located under X:\OneSite\<OS architecture>\OneSiteDownloader.exe
When specifying the task sequence variable SMSTSDownloadProgram, the value can set to: %systemdrive%\OneSite\%processor_architecture%\OneSiteDownloader.exe

A log will be created in the same location the script is executed from. If a previous log file exists in the same location, it will be deleted.
 