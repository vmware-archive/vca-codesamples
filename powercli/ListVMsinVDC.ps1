# This script list the VMs in a given VDC
# Reads as inputs User, Password, Region, VDC

$userid = Read-Host 'Enter userid'
$password = Read-Host 'Enter password' -AsSecureString
$region = Read-Host 'Enter the Region you want to work with [e.g. us-ca, us-vi, uk-sl, au-so, de-ge]' 
$myOrgVdc = Read-Host 'Enter the OrgVdc you want a list of VMs of'
$WarningPreference = "SilentlyContinue"
#import-module vmware.vimautomation.core
$mycreds = New-Object System.Management.Automation.PSCredential ($userid, $password)
Connect-PIServer -vCA -Credential $mycreds -WarningAction 0 -ErrorAction 0
$regionstar = $region + "*"
Write-Host $regionstar                      
Get-PIComputeInstance -Region $regionstar | Connect-PIComputeInstance -WarningAction 0 -ErrorAction 0
Get-CIVM | Format-Table 