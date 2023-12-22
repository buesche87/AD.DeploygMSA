<#
    .SYNOPSIS
        This script deploys a new gMSA to the computer running it
		
		- Create a new "Local Admins" AD-group for the target computer
		- Add the defined gMSA to this group
		- Add the new AD-group to the computers Local Admin group
		- Add the computer account to the AD-Group elegible for managing the gMSA
		- Renew Kerberos Ticket
		- Install gMSA

    .INPUTS
        None

    .OUTPUTS
        None

    .LINK
        Disclamer:https://raw.githubusercontent.com/tn-ict/Public/master/Disclaimer/DISCLAIMER

    .NOTES
        Author:  Andreas Bucher
        Version: 0.0.1
        Date:    22.12.2023
        Purpose: Installs a gMSA

    .EXAMPLE
        .\DeploygMSA.ps1
        
        You can distribute this script to the NETLOGON folder and create a "Run Once" task in the VM Customization policy
		Add the following parameter:
		
		cmd.exe /C Powershell.exe –ExecutionPolicy Bypass -file \\domain.local\NETLOGON\DeploygMSA.ps1
		
#>

#----------------------------------------------------------[Declarations]----------------------------------------------------------

# Start as admin
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$pwd'; & '$PSCommandPath';`"";
    exit;
}

# Set console encoding to UTF-8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[cultureinfo]::CurrentUICulture = 'de-CH'

Write-Host "`nInstalliere gMSA für Veeam`n" -BackgroundColor Green -ForegroundColor White

# Server parameters
$ServerName    = "$env:COMPUTERNAME"
$ServersAMAcc  = $ServerName+"$"
$DomainName    = "domain.local"
$LocalAdminGrp = "Administrators"

# gMSA parameters 
$gMSA_Veeam   = "gmsa.veeam$"
$gMSA_ADGroup = "gmsa.grp.veeam"

# AD-group parameters
$LA_ADGroupName = "G_LA_"+$ServerName
$LA_ADGroupDesc = "Lokale Admins "+$ServerName
$LA_ADGroupPath = "OU=Security Groups,OU=Customer,DC=domain,DC=local"

#----------------------------------------------------------[Execution]-----------------------------------------------------------

# Create new AD-group
New-ADGroup -Name $LA_ADGroupName -GroupCategory Security -GroupScope Global -DisplayName $LA_ADGroupName -Path $LA_ADGroupPath -Description $LA_ADGroupDesc

# Add the gMSA to this group
ADD-ADGroupMember -identity $LA_ADGroupName -members $gMSA_Veeam

# Wait for the domain
Write-Host "Warte 30s auf die Domäne..."
Sleep 30

# Declare new AD-group as local admin
Add-LocalGroupMember -Group $LocalAdminGrp -Member "$DomainName\$LA_ADGroupName"

# Add computer account to the gMSA group
ADD-ADGroupMember -identity $gMSA_ADGroup -members $ServersAMAcc

# Renew Kerberos Ticket
klist.exe -li 0x3e7 purge
gpupdate /force

# Install gMSA
Install-AdServiceAccount $gMSA_Veeam