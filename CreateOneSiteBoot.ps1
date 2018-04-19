#========================================================================
# Title:		ConfigMgr OneSite Boot Image Creation Script
# Updated on:   04/20/2018
# Created by:   Gerry Borger
# Edited by:    Chaz Spahn
# Organization: Adaptiva
# Filename:     CreateOneSiteBoot.ps1
# Usage:		This script has two required parameters. 
#				CreateOneSiteBoot.ps1 -bootimgarch "x86 or x64" -onesitesource "Path to OneSiteDownloader files"
#				Please see the readme for additional parameters and switches. 
#========================================================================
Param(
	[Parameter(Mandatory=$True)]
	[string]$bootImgArch,
	[string]$OneSiteSource,

	[Parameter(Mandatory=$False)]
	[string]$BootImageID,
    [string]$SiteServer,
	[string]$DP,
	[string]$MP,
	[string]$MediaMode,
	[string]$YearstoExpire,
	[String]$Password,
	[string]$CertPath,
	[String]$CertPassword,
	[string]$UserDeviceAffinity,
	[string]$UpdateBootImagePath,
	[switch]$UnknownSupport,
	[switch]$CMDSupport
)

#========================================================================
# Logging and Functions
#========================================================================
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
$ScriptVer = "6.0"
$logfile = "$ScriptDir\CreateOneSiteBoot_$bootImgArch.log"
if ((Test-Path $logfile) -eq $true)
{
	Remove-Item $logfile -force
}
function log($string, $color)
{
   if ($Color -eq $null) {$color = "white"}
   write-host $string -foregroundcolor $color
   $string | out-file -Filepath $logfile -append
}
function quitscript
{
	Log "A log file has been saved here: $logfile" yellow
	Log "Quitting script."
	Set-Location $OrigLocation
	Exit
}
$OrigLocation = Get-Location
Log "Started script logging for CreateOneSiteBoot Script, version $ScriptVer." yellow
Log "In the case where an error occurs, please review the log file which has been saved here: $logfile" yellow

$ConfigMgrPShellModule = $Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5) + '\ConfigurationManager.psd1'
Log "Importing ConfigMgr PowerShell modules from: $ConfigMgrPShellModule"
import-module ($ConfigMgrPShellModule) 
$PSD = Get-PSDrive -PSProvider CMSite 
$SiteCode = $PSD.Name 
Set-Location"$($PSD):"

#========================================================================
# Argument Handling
#========================================================================
if ($bootImgArch -eq "x86")
{
	$procArch = "X86"
	$arch = "X86"
	$OSDwn = "OneSiteDownloader.exe"
	$oobarch = "i386"
}
elseif ($bootImgArch -eq "x64")
{
	$procArch = "AMD64"
	$arch = "X64"
	$OSDwn = "OneSiteDownloader64.exe"
	$oobarch = "X64"
}
elseif (!$bootImgArch)
{
	Log "The paramter -bootImgarch was not used command line. Defaulting to x64." yellow
	$procArch = "AMD64"
	$arch = "X64"
	$OSDwn = "OneSiteDownloader64.exe"
	$oobarch = "X64"
}
else
{
	Log "The parameter -bootImgArch was used with the value: $bootImgArch. Only x86 or x64 are supported parameters." red
	quitscript
}
if (!$SiteServer)
{	
	$SiteServer = (Get-WmiObject win32_computersystem).DNSHostName + "." + (Get-WmiObject win32_computersystem).Domain
	Log "Since the -SiteServer parameter was not specified, this machine: $SiteServer will be used."
}
if (!$UpdateBootImagePath)
{
	if (!$MP)
	{
		$MP = $SiteServer
		Log "Since the -MP parameter was not specified, the value for SiteServer will be used: $SiteServer."
	}
	if (!$DP) 
	{
		$DP = $SiteServer 
		Log "Since the -DP parameter was not specified, the value for SiteServer will be used: $SiteServer."
	}
	if ($BootImageID)
	{
		Log "The -BootImageID parameter was used. Querying ConfigMgr for information on boot image: $BootImageID."
		$BootImage = Get-CMBootImage -ID $BootImageID
		$BaseBootImageName = $BootImage.Name
		$BaseBootImageArch = $BootImage.Architecture
		$BaseBootImgPath = $BootImage.ImagePath
		$BaseBootImgPkgSourcePath = $BootImage.PkgSourcePath
		if (!$BootImage)
		{
			Log "No data was returned from ConfigMgr for the boot image: $BootImageID." red
			Log "Check the value you provided for the -BootImageID parameter." red
			quitscript
		}
		Log "Checked the boot image: $BootImageID information in ConfigMgr."
		Log "Boot image name: $BaseBootImageName."
		Log "Boot image architecture: $BaseBootImageArch."
		Log "Boot image path: $BaseBootImgPath."
		Log "Boot image package source path: $BaseBootImgPkgSourcePath."
		Log "Validating that these two files exist."
		Set-Location$env:SystemDrive
		if ((Test-Path $BaseBootImgPath) -eq $false)
		{
			Log "Unable to find the file: $BaseBootImgPath. Delete the boot image: $BootImage from ConfigMgr and try again." red
			quitscript
		}
		if ((Test-Path $BaseBootImgPkgSourcePath) -eq $false)
		{
			Log "Unable to find the file: $BaseBootImgPkgSourcePath. Delete the boot image: $BootImage from ConfigMgr and try again." red
			quitscript
		}
		else
		{
			$BaseBootImgPkgSourceFileName = Split-Path -Path $BaseBootImgPkgSourcePath -Leaf	
		}
		Log "Checking if the specified boot image is the same architecture as referenced in the command line."
		if ($BaseBootImageArch -eq "9")
		{
			if ($bootImgArch -eq "x86")
			{
				Log "The value for the parameter -bootImgArch is x86, but the boot image referenced: $BootImageID is an x64 based boot image." red
				Log "Re-run the script with the parameter -bootImgArch set to x64." red
				quitscript
			}
		}
		elseif ($BaseBootImageArch -eq "0")
		{
			if ($bootImgArch -eq "x64")
			{
				Log "The value for the parameter -bootImgArch is x64, but the boot image referenced: $BootImageID is an x86 based boot image." red
				Log "Re-run the script with the parameter -bootImgArch set to x86." red
				quitscript
			}
		}
		else
		{
			Log "Unable to get the architecture of the boot image via ConfigMgr. Make sure you entered the correct value for the -BootImageID parameter." red
			quitscript
		}
		$BootImgPath = "\\$SiteServer\SMS_$SiteCode\OSD\boot\OneSiteBoot\$arch\OneSiteBoot$arch.wim"
		$BootImgDir = "\\$SiteServer\SMS_$SiteCode\OSD\boot\OneSiteBoot\$arch"
		if ($BaseBootImgPath -eq $BootImgPath)
		{
			Log "The boot image path of the provided boot image ID: $BootImgID is: $BaseBootImgPath." yellow
			Log "This is the same location in which the script creates the new boot image so the source boot image will be copied into another folder." yellow
			$Random = Get-Random
			New-Item -Path $BootImgDir\OneSiteBoot_$Random -ItemType Directory -Force
			Copy-Item -Path $BaseBootImgPath -Destination $BootImgDir\OneSiteBoot_$Random -Force
			Move-Item -Path $BaseBootImgPkgSourcePath -Destination $BootImgDir\OneSiteBoot_$Random -Force
			if ((Test-Path $BootImgDir\OneSiteBoot_$Random\OneSiteBoot$arch.wim) -eq $false)
			{
				Log "The boot image failed to copy to the temp directory: $BootImgDir\OneSiteBoot_$Random." red
				Log "The script cannot continue. Validate that you have correct permissions." red
				quitscript
			}
			else
			{
				Log "The base boot image files were successfully copied to the folder: $BootImgDir\OneSiteBoot_$Random." yellow
				Log "Modifying the old boot image in ConfigMgr to reflect the new path." yellow
				$BootImages = Get-WmiObject -Query "Select * from SMS_BootImagePackage where PackageID = '$BootImageID'" -Namespace "Root\SMS\Site_$SiteCode"  -ComputerName $SiteServer
				foreach ($BootImage in $BootImages) 
				{
					$BootImage = [wmi]"$($BootImage.__PATH)"
					$BootImage.PkgSourcePath = "$BootImgDir\OneSiteBoot_$Random\$BaseBootImgPkgSourceFileName"
					$BootImage.Put()
					$BootImage = [wmi]"$($BootImage.__PATH)"
					$BootImage.ImagePath = "$BootImgDir\OneSiteBoot_$Random\OneSiteBoot$arch.wim"
					$BootImage.Put()
				}
				$NewName = "OneSite Boot ($arch)_Old_$Random"
				Log "Renaming the boot image to: $NewName." yellow
				Set-Location"$($PSD):"
				Set-CMBootImage -Id $BootImageID -NewName $NewName 
				$BaseBootImgPath = "$BootImgDir\OneSiteBoot_$Random\OneSiteBoot$arch.wim"
				Set-Location"$($PSD):"
			}
		}
	}
	else
	{	
		$BootImgPath = "\\$SiteServer\SMS_$SiteCode\OSD\boot\OneSiteBoot\$arch\OneSiteBoot$arch.wim"
		$BootImgDir = Split-Path -Path $BootImgPath	
	}
	if (!$MediaMode) 
	{
		$MediaMode = "Dynamic"
	}
	elseif ($MediaMode -eq "Dynamic"){}
	elseif ($MediaMode -eq "SiteBased"){}
	else
	{
		Log "The value set for the -MediaMode parameter: $MediaMode is not a supported value." red
		Log "-MediaMode can only be set to 'SiteBased' or 'Dynamic' (Default)" red
		quitscript
	}
	if (!$UserDeviceAffinity)
	{
		$Affinity = "DoNotAllow"
	}
	elseif ($UserDeviceAffinity -eq "DoNotAllow")
	{
		$Affinity = "DoNotAllow"
	}
	elseif ($UserDeviceAffinity -eq "AdministratorApproval")
	{
		$Affinity = "AdministratorApproval"
	}
	elseif ($UserDeviceAffinity -eq "AutoApproval")
	{
		$Affinity = "AutoApproval"	
	}
	else
	{
		Log "The value set for the -UserDeviceAffinity parameter: $UserDeviceAffinity is not a supported value." red
		Log "-UserDeviceAffinity can only be set to 'AdministratorApproval', 'AutoApproval', or 'DoNotAllow' (Default)" red
		quitscript
	}
	if ($Password)
	{
		$SecurePwd = ConvertTo-SecureString $Password -AsPlainText -Force
	}
	if ($CertPassword)
	{
		$SecureCertPwd = ConvertTo-SecureString $CertPassword -AsPlainText -Force
		if (!$CertPath)
		{
			Log "The parameter -CertPassword was used, but the -CertPath parameter was not." red
			Log "The parameters -CertPassword and -CertPath must be used together." red
			quitscript
		}
	}
	if ($CertPath)
	{
		if ((Test-Path $CertPath) -eq $false)
		{
			Log "The parameter -CertPath was used: $CertPath , but the file can't be found." red
			quitscript
		}
		if (!$CertPassword)
		{
			Log "The parameter -CertPath was used, but the parameter -CertPassword was not." red
			Log "The parameters -CertPassword and -CertPath must be used together." red
			quitscript
		}
		if ($YearstoExpire)
		{
			Log "The parameter -CertPath was used with the -YearstoExpire parameter." yellow
			Log "The -YearstoExpire parameter is only applicable when using a self-signed certificate and will be ignored." yellow
		}
	}
	if (!$YearstoExpire) {$YearstoExpire = "2"}
	$StartDate = ([datetime]::Now)
	$ExpirationDate = ([datetime]::Now.AddYears($YearstoExpire))
}
Log " "
Log "========================================================================"
Log "This script will be run with the following settings:"
Log "========================================================================"
Log "Boot Image Architecture: $arch"
Log "OneSite Source location: $OneSiteSource"
if ($BootImageID)
{
	Log "Boot Image ID: $BootImageID"
}
if (!$UpdateBootImagePath)
{
	Log "Boot Image Directory: $BootImgDir"
	Log "Boot Image Path: $BootImgPath"
	Log "Site Server: $SiteServer"
	Log "Management Point: $MP"
	Log "Distribution Point: $DP"
	Log "Boot Image Media Mode: $MediaMode"
	Log "Self-signed certificate expiration date: $ExpirationDate"
	if ($UnknownSupport){Log "Unknown Computer Support: Enabled"} else{Log "Unknown Computer Support: Disabled"}
	if ($CMDSupport){Log "Command Prompt Support: Enabled"} else{Log "Command Prompt Support: Disabled"}
	if ($Password){Log "Password Protection: Enabled"} else {Log "Password Protection: Disabled"}
}
else
{
	Log "Boot Image Update Path: $BootImageUpdatePath"
}
Log "========================================================================"
Log " "

Log "Checking if this operating system is Windows Server 2008."
$OSQuery = Get-WmiObject -NameSpace "root\cimv2" -query "Select * from Win32_OperatingSystem" -ComputerName $SiteServer 
foreach($OS in $OSQuery)
{
	if ($OS.Caption.contains("2008") -eq $true) 
	{
		Log "Windows Server 2008 is not supported by this script. Quitting script." red
		quitscript
	}
}

Log "Checking if files are available in OneSite Source location."
if ((Test-Path $OneSiteSource\$OSDwn) -eq $false)
{
	Log "Unable to access the file: $OneSiteSource\$OSDwn." red
	Log "Check that the parameter -OneSiteSource is accurate and contains $OSDwn." red
	quitscript
}
if ($UpdateBootImagePath)
{
	if (!$BootImageID)
	{
		Log "The -UpdateBootImagePath parameter was specified, but the parameter -BootImageID was not provided. Re-run the script with the -BootImageID parameter." red
		quitscript
	}
	if ((Test-Path $UpdateBootImagePath) -eq $false)
	{
		Log "Unable to validate the path to the boot image to update: $UpdateBootImagePath. The path must be a fixed drive on the local system and not a UNC path." red
		Log "Please run the script again with the correct path. Quitting script." red
		quitscript
	}
	$BootImage = Get-CMBootImage -ID $BootImageID
	Log "Checking if the specified boot image is the same architecture as referenced in the command line."
	if ($BootImage.Architecture -eq "9")
	{
		if ($bootImgArch -eq "x86")
		{
			Log "The value for the parameter -bootImgArch is x86, but the boot image referenced: $BootImageID is an x64 based boot image." red
			Log "Re-run the script with the parameter -bootImgArch set to x64." red
			quitscript
		}
	}
	elseif ($BootImage.Architecture -eq "0")
	{
		if ($bootImgArch -eq "x64")
		{
			Log "The value for the parameter -bootImgArch is x64, but the boot image referenced: $BootImageID is an x86 based boot image." red
			Log "Re-run the script with the parameter -bootImgArch set to x86." red
			quitscript
		}
	}
	else
	{
		Log "Unable to get the architecture of the boot image via ConfigMgr. Make sure you entered the correct value for the -BootImageID parameter." red
		quitscript
	}
	$BootImgDir = Split-Path -Path $UpdateBootImagePath
	If ((Test-Path -Path $BootImgDir\staging) -eq $true)
	{
		Remove-Item -Path $BootImgDir\staging -Recurse -Force
	}
	New-Item $BootImgDir\staging -Type directory -force
	Log "Mounting the specified boot WIM: $UpdateBootImagePath"
	DISM.exe /Mount-Image /ImageFile:"$UpdateBootImagePath" /Index:1 /MountDir:"$BootImgDir\staging"
	Log "Checking that the mount operation was successful."
	If ((Test-Path -Path $BootImgDir\staging\Windows) -eq $false)
	{
		Log "The boot image did not successfully mount. Review the DISM.log and retry."
		quitscript
	}
	Log "Copying $arch OneSiteDownloader to mounted WIM folder."
	New-Item $BootImgDir\staging\OneSite\$procArch -Type Directory -force
	if ((Test-Path -Path $BootImgDir\staging\OneSite\$procArch\OneSiteDownloader.exe) -eq $true)
	{
		Log "Found a copy of OneSiteDownloader.exe in the path. Deleting..."
		Remove-Item -Path $BootImgDir\staging\OneSite\$procArch\OneSiteDownloader.exe -Force
	}
	Copy-Item $OneSiteSource\$OSDwn $BootImgDir\staging\OneSite\$procArch -force
	Rename-Item $BootImgDir\staging\OneSite\$procArch\$OSDwn OneSiteDownloader.exe
	if ($bootImgArch = "X64")
	{
		Log "Copying the x86 version of OneSiteDownloader to the mounted WIM folder."
		New-Item $BootImgDir\staging\OneSite\X86 -Type Directory -force
		if ((Test-Path -Path $BootImgDir\staging\OneSite\X86\OneSiteDownloader.exe) -eq $true)
		{
			Log "Found a copy of OneSiteDownloader.exe in the path. Deleting..."
			Remove-Item -Path $BootImgDir\staging\OneSite\X86\OneSiteDownloader.exe -Force
		}
		Copy-Item $OneSiteSource\OneSiteDownloader.exe $BootImgDir\staging\OneSite\X86 -force
	}	
	Log "Checking if OneSiteDownloader.exe copied successfully."
	$dismAction = '/commit'
	if ((Test-Path $BootImgDir\staging\OneSite\$procArch\OneSiteDownloader.exe) -eq $false)
	{
		Log "OneSiteDownloader.exe failed to copy." red
		$dismAction = '/discard'
	}
	else
	{
		Log "OneSiteDownloader.exe copied successfully."
	}
	Log "Executing DISM to unmount the WIM."
	DISM.exe /UnMount-Image /MountDir:$BootImgDir\staging $dismAction
	if ($dismAction -eq '/commit')
	{
		Log "The WIM was unmounted and committed."
		Log "Updating distribution points for boot WIM with package ID: $BootImageID."
		Update-CMDistributionPoint -BootImageId $BootImageID
		$BootImages = Get-WmiObject -Query "Select * from SMS_BootImagePackage where PackageID = '$BootImageID'" -Namespace "Root\SMS\Site_$SiteCode"  -ComputerName $SiteServer
		foreach ($BootImage in $BootImages) 
		{
			if ($CMDSupport)
			{
				Log "Enabling Command prompt support in boot image."
				$BootImage = [wmi]"$($BootImage.__PATH)"
				$BootImage.EnableLabShell = $true
				$BootImage.Put()
			}
			$Version = $BootImage.ImageOSVersion
			if ($Version)
			{
				Log "Setting boot image version so it can be seen in the ConfigMgr console."
				$BootImage = [wmi]"$($BootImage.__PATH)"
				$BootImage.Version = $Version
				$BootImage.Put()
			}
		}
	}
	else
	{
		Log "OneSiteDownloader.exe failed to copy to the mount directory. The WIM was unmounted and discarded." yellow
		quitscript
	}
	Log "Deleting the mount directory: $BootImgDir\staging."
	Remove-Item -Path $BootImgDir\staging -Force
	Log "The boot image has been unmounted successfully and is ready to be used."
	quitscript
}
Log "Checking the location where we will create the boot image."
if ((Test-Path $("filesystem::$BootImgPath")) -eq $true)
{
	Log "A boot WIM file exists where we plan to create the boot image: $BootImgPath."
	Log "Checking if the boot WIM is in ConfigMgr."
	Set-Location"$($PSD):"
	$BootImages = Get-CMBootImage
	foreach ($BootImage in $BootImages)
	{
		if ($BootImage.ImagePath -eq $BootImgPath)
		{
			$FoundBootImgName = $BootImage.Name
			$FoundBootImgPath = $BootImage.ImagePath
			$FoundBootImgPkgSourcePath = $BootImage.PkgSourcePath
			$FoundBootImgPkgID = $BootImage.PackageID
			Set-Location$env:SystemDrive
			if ((Test-Path $FoundBootImgPkgSourcePath) -eq $false)
			{
				Log "Unable to find the file: $FoundBootImgPkgSourcePath. Delete the boot image: $FoundBootImgName from ConfigMgr and try again."
				quitscript
			}
			else
			{
				$FoundBootImgPkgSourceFileName = Split-Path -Path $FoundBootImgPkgSourcePath -Leaf
			}
			Log "Found a boot image with the same path this script uses to create the boot WIM. Package ID: $FoundBootImgPkgID, Name: $FoundBootImgName." yellow
			$Random = Get-Random 
			Set-Location$env:SystemDrive
			Log "This is the same location in which the script creates the new boot image so the source boot image will be copied into another folder." yellow
			New-Item -Path $BootImgDir\OneSiteBoot_$Random -ItemType Directory -Force
			Move-Item -Path $FoundBootImgPath -Destination $BootImgDir\OneSiteBoot_$Random -Force
			Move-Item -Path $FoundBootImgPkgSourcePath -Destination $BootImgDir\OneSiteBoot_$Random -Force
			if ((Test-Path $BootImgDir\OneSiteBoot_$Random\OneSiteBoot$arch.wim) -eq $false)
			{
				Log "The boot image failed to copy to the temp directory: $BootImgDir\OneSiteBoot_$Random." red
				Log "The script can not continue." red
				quitscript
			}
			else
			{
				Log "The boot image was copied successfully to the folder: $BootImgDir\OneSiteBoot_$Random." yellow
				Log "Modifying the old boot image in ConfigMgr to reflect the new path." yellow
				$BootImages = Get-WmiObject -Query "Select * from SMS_BootImagePackage where PackageID = '$FoundBootImgPkgID'" -Namespace "Root\SMS\Site_$SiteCode"  -ComputerName $SiteServer
				foreach ($BootImage in $BootImages) 
				{
					$BootImage = [wmi]"$($BootImage.__PATH)"
					$BootImage.PkgSourcePath = "$BootImgDir\OneSiteBoot_$Random\$FoundBootImgPkgSourceFileName"
					$BootImage.Put()
					$BootImage = [wmi]"$($BootImage.__PATH)"
					$BootImage.ImagePath = "$BootImgDir\OneSiteBoot_$Random\OneSiteBoot$arch.wim"
					$BootImage.Put()
				}
				$NewName = "OneSite Boot ($arch)_Old_$Random"
				Log "Renaming the boot image to: $NewName." yellow
				Set-Location"$($PSD):"
				Set-CMBootImage -Id $FoundBootImgPkgID -NewName $NewName 
			}
		}
	}
	if (!$FoundBootImgName)
	{
		Log "The script did not find a boot image in ConfigMgr with the same path. Regardless, the file will be moved to another folder." yellow
		$Random = Get-Random 
		Set-Location$env:SystemDrive
		New-Item -Path $BootImgDir\OneSiteBoot_$Random -ItemType Directory -Force
		Move-Item -Path $BootImgPath -Destination $BootImgDir\OneSiteBoot_$Random -Force
		if ((Test-Path $BootImgDir\OneSiteBoot_$Random\OneSiteBoot$arch.wim) -eq $false)
		{
			Log "The boot image failed to move to the temp directory: $BootImgDir\OneSiteBoot_$Random." red
			Log "The script can not continue." red
			quitscript
		}
	}
}
Set-Location$env:SystemDrive
If ((Test-Path -Path $BootImgDir\staging) -eq $true)
{
	Remove-Item -Path $BootImgDir\staging -Recurse -Force
}
New-Item $BootImgDir\staging -Type directory -force

if ($BootImageID)
{
	Log "Copying current boot image: $BootImageID to $BootImgDir."
	if ((Test-Path -Path $BaseBootImgPath) -eq $false)
	{
		Log "Unable to find the file: $BaseBootImgPath. Unable to create the boot image from this file." red
		quitscript
	}
	Copy-Item $BaseBootImgPath $BootImgDir -force
	$BaseImageFileName = Split-Path -Path $BaseBootImgPath -Leaf -Resolve
	Rename-Item $BootImgDir\$BaseImageFileName OneSiteBoot$arch.wim
}
else
{
	Log "Copying out-of-the-box boot image to $BootImgDir."
	Copy-Item "\\$SiteServer\SMS_$SiteCode\OSD\boot\$oobarch\boot.wim" $BootImgDir -force
	Rename-Item $BootImgDir\boot.wim OneSiteBoot$arch.wim
}

Set-Location"$($PSD):"
Log "Creating new boot image: $BootImgPath"
New-CMBootImage -Index 1 -Name "OneSite Boot ($arch)" -Path $BootImgPath

Log "Boot image created. Querying for boot image package ID."
$BootImages = Get-WmiObject -Query "Select * from SMS_BootImagePackage where Name like 'OneSite Boot ($arch)'" -Namespace "Root\SMS\Site_$SiteCode"  -ComputerName $SiteServer
if ($BootImages -ne $null) 
{
    if (($BootImages | Measure-Object).Count -eq 1) 
	{
		foreach ($BootImage in $BootImages) 
		{
			$PkgID = $BootImage.PackageID
			Log "Boot image package ID is: $PkgID."
			if ($CMDSupport)
			{
				Log "Enabling Command prompt support in boot image."
				$BootImage = [wmi]"$($BootImage.__PATH)"
				$BootImage.EnableLabShell = $true
				$BootImage.Put()
			}
			$Version = $BootImage.ImageOSVersion
			if ($Version)
			{
				Log "Setting boot image version so it can be seen in the ConfigMgr console."
				$BootImage = [wmi]"$($BootImage.__PATH)"
				$BootImage.Version = $Version
				$BootImage.Put()
			}
        }
	}
	else 
	{
		Log "More than one boot image with the name OneSite Boot ($arch) was returned. Unable to continue." red
		quitscript
    }
}
else 
{
	Log "Unable to obtain the Boot Image info from ConfigMgr. The boot image failed to create." red
	quitscript
}

Log "Sending boot image to distribution point: $DP. The script will continue once complete."
Start-CMContentDistribution -BootImageId $PkgID -DistributionPointName $DP
Do
{
	$query = Get-WmiObject -Query "Select * from SMS_DistributionDPStatus where PackageID = '$PkgID' and Name = '$DP'" -Namespace Root\SMS\Site_$SiteCode -ComputerName $SiteServer
	foreach ($objItem in $query)
	{
		$status = $objItem.MessageState
	}
	Log "Sleeping for 30 seconds before checking content status again."
	Start-Sleep -Seconds 30
}
Until ($status -eq 1)
Log "The boot image has successfully been sent to the distribution point. Continuing script."

$ISOPath = "$Env:SYSTEMROOT\Temp\OneSiteBoot$arch.iso"
Log "Creating Task Sequence Media as an ISO file so we can extract some files." 
Log "Checking if an ISO already exists."
if ((Test-Path -Path $ISOPath) -eq $true)
{
	Log "Found a previous ISO with the same name. Deleting old ISO." 
	Remove-Item $ISOPath -force
    if ((Test-Path -Path $ISOPath) -eq $true)
    {
        Log "Unable to delete ISO file: $ISOPath." red
	    quitscript
    }
}

Log "Creating bootable task sequence media here: $ISOPath"
$BootImage = Get-CMBootImage -ID $PkgID
$ManagementPoint = Get-CMManagementPoint -SiteSystemServerName $MP
$DistributionPoint = Get-CMDistributionPoint -SiteCode $SiteCode -SiteSystemServerName $DP
if ($Password)
{
	if ($CertPath)
	{
		if ($UnknownSupport)
		{
			New-CMBootableMedia -CertificatePath $CertPath -CertificatePassword $SecureCertPwd -MediaType CdDvd -MediaPassword $SecurePwd -BootImage $BootImage -DistributionPoint $DistributionPoint -ManagementPoint $ManagementPoint -MediaMode $MediaMode -Path $ISOPath -UserDeviceAffinity $Affinity -AllowUnattended -AllowUnknownMachine
		}
		else
		{
			New-CMBootableMedia -CertificatePath $CertPath -CertificatePassword $SecureCertPwd -MediaType CdDvd -MediaPassword $SecurePwd -BootImage $BootImage -DistributionPoint $DistributionPoint -ManagementPoint $ManagementPoint -MediaMode $MediaMode -Path $ISOPath -UserDeviceAffinity $Affinity -AllowUnattended
		}
	}
	else
	{
		if ($UnknownSupport)
		{
			New-CMBootableMedia -MediaType CdDvd -MediaPassword $SecurePwd -BootImage $BootImage -DistributionPoint $DistributionPoint -ManagementPoint $ManagementPoint -MediaMode $MediaMode -Path $ISOPath -UserDeviceAffinity $Affinity -CertificateStartTime $StartDate -CertificateExpireTime $ExpirationDate -AllowUnattended -AllowUnknownMachine
		}
		else
		{
			New-CMBootableMedia -MediaType CdDvd -MediaPassword $SecurePwd -BootImage $BootImage -DistributionPoint $DistributionPoint -ManagementPoint $ManagementPoint -MediaMode $MediaMode -Path $ISOPath -UserDeviceAffinity $Affinity -CertificateStartTime $StartDate -CertificateExpireTime $ExpirationDate -AllowUnattended
		}
	}
}
else
{
	if ($CertPath)
	{
		if ($UnknownSupport)
		{
			New-CMBootableMedia -CertificatePath $CertPath -CertificatePassword $SecureCertPwd -MediaType CdDvd -BootImage $BootImage -DistributionPoint $DistributionPoint -ManagementPoint $ManagementPoint -MediaMode $MediaMode -Path $ISOPath -UserDeviceAffinity $Affinity -AllowUnattended -AllowUnknownMachine
		}
		else
		{
			New-CMBootableMedia -CertificatePath $CertPath -CertificatePassword $SecureCertPwd -MediaType CdDvd -BootImage $BootImage -DistributionPoint $DistributionPoint -ManagementPoint $ManagementPoint -MediaMode $MediaMode -Path $ISOPath -UserDeviceAffinity $Affinity -AllowUnattended
		}
	}
	else
	{
		if ($UnknownSupport)
		{
			New-CMBootableMedia -MediaType CdDvd -BootImage $BootImage -DistributionPoint $DistributionPoint -ManagementPoint $ManagementPoint -MediaMode $MediaMode -Path $ISOPath -CertificateStartTime $StartDate -CertificateExpireTime $ExpirationDate -AllowUnattended -AllowUnknownMachine
		}
		else
		{
			New-CMBootableMedia -MediaType CdDvd -BootImage $BootImage -DistributionPoint $DistributionPoint -ManagementPoint $ManagementPoint -MediaMode $MediaMode -Path $ISOPath -CertificateStartTime $StartDate -CertificateExpireTime $ExpirationDate -AllowUnattended
		}		
	}
}

if ((Test-Path -Path $ISOPath) -eq $false)
{
	Log "The bootable task sequence media ISO creation failed." red
	Remove-CMBootImage -ID $PkgID -Force
	Set-Location$env:SystemDrive
	Log "Deleting boot image WIM from the file system." yellow
	Remove-Item -Path $BootImgPath -Force
	quitscript
}

Log "Mounting the ISO: $ISOPath"
Mount-DiskImage $ISOPath
Start-Sleep -Seconds 5

$mountResult = Get-DiskImage -ImagePath $ISOPath | Get-Volume
$mountvolume  = ($mountResult | Get-Volume).DriveLetter + ":"

Set-Location$env:SystemDrive
Log "Mount complete. Checking access to the mount volume: $mountvolume."
if ((Test-Path -Path $mountvolume\SMS\Data\TsmBootstrap.ini) -eq $true)
{
	Log "Able to access the mount volume. Copying files to boot image location."
	Copy-Item $mountvolume\SMS\data\TsmBootstrap.ini $BootImgDir -force
	Copy-Item $mountvolume\SMS\data\variables.dat $BootImgDir -force
	If ((Test-Path -Path $BootImgDir\tsmbootstrap.ini) -eq $false)
	{
		Log "Unable to copy $mountvolume\SMS\data\TsmBootstrap.ini to $BootImgDir." red
		quitscript
	}
	If ((Test-Path -Path $BootImgDir\variables.dat) -eq $false)
	{
		Log "Unable to copy $mountvolume\SMS\data\variables.dat to $BootImgDir." red 
		quitscript
	}
}
else
{
	Log "Unable to access files in the mount directory." red
	quitscript
}
Log "Dismounting mounted ISO."
Dismount-Diskimage -imagepath $ISOPath
Log "Deleting the ISO file $ISOPath"
Remove-Item -Path $ISOPath -Force

$BootImgFixedPath = $Env:SMS_LOG_PATH.Substring(0,$Env:SMS_LOG_PATH.Length-4) + 'OSD\boot\OneSiteBoot\' + $arch
Log "Mounting the OneSite Boot ($arch) WIM: $BootImgFixedPath"
DISM.exe /Mount-Image /ImageFile:"$BootImgFixedPath\OneSiteBoot$arch.wim" /Index:1 /MountDir:"$BootImgFixedPath\staging"

Log "Checking to see if the mount was successful."
if ((Test-Path -Path $BootImgDir\staging\Windows) -eq $true)
{
	Log "Copying files into mounted WIM folder."
	New-Item $BootImgDir\staging\SMS\DATA -Type Directory -Force
	Log "Copying tsmbootstrap.ini."
	Copy-Item $BootImgDir\TsmBootstrap.ini $BootImgDir\staging\SMS\DATA -force
	Log "Copying variables.dat."
	Copy-Item $BootImgDir\variables.dat $BootImgDir\staging\SMS\DATA -force
	Remove-Item $BootImgDir\TsmBootstrap.ini -Force
	Remove-Item $BootImgDir\variables.dat -force
	
	Log "Copying $arch OneSiteDownloader to mounted WIM folder."
	New-Item $BootImgDir\staging\OneSite\$procArch -Type Directory -force
	if ((Test-Path -Path $BootImgDir\staging\OneSite\$procArch\OneSiteDownloader.exe) -eq $true)
	{
		Log "Found a copy of OneSiteDownloader.exe in the path. Deleting..."
		Remove-Item -Path $BootImgDir\staging\OneSite\$procArch\OneSiteDownloader.exe -Force
	}
	Copy-Item $OneSiteSource\$OSDwn $BootImgDir\staging\OneSite\$procArch -force
	Rename-Item $BootImgDir\staging\OneSite\$procArch\$OSDwn OneSiteDownloader.exe
	if ($bootImgArch = "X64")
	{
		Log "Copying the x86 version of OneSiteDownloader to the mounted WIM folder."
		New-Item $BootImgDir\staging\OneSite\X86 -Type Directory -force
		if ((Test-Path -Path $BootImgDir\staging\OneSite\X86\OneSiteDownloader.exe) -eq $true)
		{
			Log "Found a copy of OneSiteDownloader.exe in the path. Deleting..."
			Remove-Item -Path $BootImgDir\staging\OneSite\X86\OneSiteDownloader.exe -Force
		}
		Copy-Item $OneSiteSource\OneSiteDownloader.exe $BootImgDir\staging\OneSite\X86 -force
	}
	$CMToolsDir = $Env:SMS_LOG_PATH.Substring(0,$Env:SMS_LOG_PATH.Length-4) + 'Tools'
	if ($arch -eq "x64")
	{
		Log "Executing CMTrace to capture $arch version."
		&$CMToolsDir\CMTrace.exe
		if ((Test-Path -Path $ENV:SYSTEMDRIVE\CMTrace.exe) -eq $True)
		{
    		Remove-Item $ENV:SYSTEMDRIVE\CMTrace.exe -force
    		Log "Old CMTrace file deleted."
		}
		Start-Sleep -Seconds 5

		$CMTraces = (Get-Process | Where-Object {$_.Description -EQ "cmtrace_amd64.exe"} | Select Name, Path)
		foreach ($CMTrace in $CMTraces)
		{
			$CMTPath = $CMTrace.path
			$CMTName = $CMTrace.Name
			
			Log "Capturing $CMTPath and copying it to C:"
			Copy-Item $CMTPath $ENV:SYSTEMDRIVE\ -force
			Rename-Item $ENV:SYSTEMDrive\$CMTName CMTrace.exe
			break
		}
	
		Log "Copying $arch CMTrace to mount directory."
		Copy-Item $ENV:SYSTEMDRIVE\CMTrace.exe $BootImgDir\staging -Force
		Log "Stopping the CMTrace process we executed."
		Stop-Process -ProcessName $CMTName
		Log "Deleting $ENV:SYSTEMDRIVE\CMTrace.exe"
		Remove-Item $ENV:SYSTEMDRIVE\CMTrace.exe -force
	}
	else
	{
		Log "Copying $arch CMTrace to mount directory."
		Copy-Item $CMToolsDir\CMTrace.exe $BootImgDir\staging -force
	}
	$dismAction = '/commit'
	Log "Checking if files were copied successfully."
	if ((Test-Path $BootImgDir\staging\SMS\DATA\TsmBootstrap.ini) -eq $false)
	{
		Log "TsmBootstrap.ini failed to copy." red
		$dismAction = '/discard'
	}
	if ((Test-Path $BootImgDir\staging\SMS\DATA\variables.dat) -eq $false)
	{
		Log "variables.dat failed to copy." red 
		$dismAction = '/discard'
	}
	if ((Test-Path $BootImgDir\staging\OneSite\$procArch\OneSiteDownloader.exe) -eq $false)
	{
		Log "OneSiteDownloader.exe failed to copy." red
		$dismAction = '/discard'
	}
	if ((Test-Path $BootImgDir\staging\cmtrace.exe) -eq $false)
	{ 
		Log "CMTrace.exe failed to copy to mount directory. Since CMtrace isn't mandatory, the WIM will be unmounted and committed." yellow
	}
}
else 
{
	Log "Unable to verify that the WIM mounted successfully." red
	quitscript
}

Set-Location"$($PSD):"
Log "Executing DISM to unmount the WIM."
DISM.exe /UnMount-Image /MountDir:$BootImgDir\staging $dismAction
if ($dismAction -eq '/commit')
{
	Log "All file copy operations were successful. The WIM was unmounted and committed."
	Log "The task sequence variable, SMSTSDownloadProgram should be set to:"
	Log "%systemdrive%\OneSite\%processor_architecture%\OneSiteDownloader.exe" yellow
	Log "Updating distribution points for boot WIM with package ID: $PkgID"
	Update-CMDistributionPoint -BootImageId $PkgID
}
else
{
	Log "Some critical files failed to copy to the mount directory. The WIM was unmounted and discarded." yellow
 	Remove-CMBootImage -ID $PkgID -Force
	Log "Deleting Boot Image WIM File" yellow
	Remove-Item $BootImgPath -force
}

Set-Location$env:SystemDrive
Log "Deleting the mount directory: $BootImgDir\staging."
Remove-Item -Path $BootImgDir\staging -Force

Log "Script is complete." yellow
quitscript


