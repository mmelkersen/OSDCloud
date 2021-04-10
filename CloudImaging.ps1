#=====================================================================================================
# Created on:   10.04.2021
# Created by:   Mattias Melkersen
# Version:	    0.2 
# Mail:         mm@mindcore.dk
# Twitter:      MMelkersen
# Function:     Sample script to get started with OSDBuilder and build Zero Touch deployments with no infrastructure.
# 
# Requirement:
# ADK needs to be installed.
#
# This script is provided As Is
# Compatible with Windows 10 and later
#=====================================================================================================

$MyWorkspace = "C:\OSDCloud"
$Mountpath = "C:\Temp\Mount_Image"

Install-Module -Name OSD -force
Import-Module OSD

#Other than making sure you have the latest OSD PowerShell Module installed, this should be the first function you start with.  This will create a more refined copy of ADK's WinPE and save it in $env:ProgramData\OSDCloud.
New-OSDCloud.template -Language da-dk -SetAllIntl da-dk -SetInputLocale da-dk -verbose
<#
    ### You can add additional Languages to the OSDCloud.template easily by adding this parameter and specifying one or more Languages.  en-us is added by default
    New-OSDCloud.Template -Language de-de,es-es,fr-fr
    
    ### If you feel brave and want to add everything, this is your command
    New-OSDCloud.Template -Language *

    ### In addition to adding Languages to the OSDCloud.template, you can set a default International Setting
    New-OSDCloud.Template -Language de-de -SetAllIntl de-de

    ### Finally, you can also set the default Keyboard layout using this parameter
    New-OSDCloud.Template -Language de-de -SetAllIntl de-de -SetInputLocale en-us
#>

#This step is to create an OSDCloud Workspace.  It's ok if you didn't create a Template first, one will be created for you automatically.  It really takes no time at all to create, it is just a copy of the Template, and it literally takes no time at all
New-OSDCloud.workspace -workspacepath $MyWorkspace

#Get Autopilot profile and download it to the OSDCloud library
$creds = Get-Credential
Connect-MSGraph -Credential $creds
Get-AutopilotProfile | Where-Object DisplayName -eq "Mindlab Production" | ConvertTo-AutopilotConfigurationJSON | Out-File -FilePath "$($MyWorkspace)\AutoPilot\Profiles\AutoPilotConfigurationFile.json" -Encoding ASCII

#Any time you need to make changes to WinPE in your current OSDCloud.workspace, you need to use this function.  Admin rights are required for this to work properly since you will be mounting a WIM
Edit-OSDCloud.winpe -workspacepath $MyWorkspace
<#
    ### Allows you to specify a Directory to add additional WinPE Drivers
    Edit-OSDCloud.winpe -DriverPath T:\Temp\WinPEDrivers
    
    ### Optionally you can include
    Edit-OSDCloud.winpe -CloudDriver Dell,Nutanix,VMware
#>

#Creates ISO file for Hyper-v to boot on
New-OSDCloud.iso -workspacepath $MyWorkspace

#Creates bootable USB for physical hardware
#New-OSDCloud.usb -workspacepath $MyWorkspace

#save-OSDCloud.usb 

#This section will create ZTI ISO file
mkdir $Mountpath
dism /mount-wim /wimfile:$MyWorkspace\Media\sources\boot.wim /index:1 /mountDir:$Mountpath

$StartnetCMDpath = "$($Mountpath)\Windows\System32\startnet.cmd"

$StartnetCMD = @'
    cls

    @ECHO OFF
    Color 0E

    ECHO.
    ECHO Loading OSDCloud... Please Wait
    ECHO.

    :: Set Configuration ::
    Set OSBuild="20H2"
    Set OSEdition="Enterprise"
    Set Culture="da-dk"
    Set DisplayRes="1600"

    :: Do NOT configure below this line. ::
    %SYSTEMROOT%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'SilentlyContinue'; (new-object -COM Shell.Application).NameSpace(17).ParseName('D:').InvokeVerb('Eject'); Install-Module OSD -Force; Set-DisRes '%DisplayRes%'; Start-OSDCloud -OSBuild '%OSBuild%' -OSEdition '%OSEdition%' -Culture '%Culture%' -ZTI"
'@

Add-Content $StartnetCMDpath "`n$StartnetCMD"

dism /unmount-wim /mountDir:$Mountpath /commit

#Creates ISO file for Hyper-v to boot on
New-OSDCloud.iso -workspacepath $MyWorkspace