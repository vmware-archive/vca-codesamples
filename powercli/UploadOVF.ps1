# This script uploads an OVF into a given vCloud Air catalog
# Reads as inputs User, Password, Region, VDC, Catalog

$userid = Read-Host 'Enter userid'
$password = Read-Host 'Enter password' -AsSecureString
$region = Read-Host 'Enter the Region you want to work with [e.g. us-ca, us-vi, uk-sl, au-so, de-ge]' 
$myOrgvdc =  Read-Host 'Enter the VDC name'
$myCatalog = Read-Host 'Enter the Catalog you want to upload to'
$WarningPreference = "SilentlyContinue"
$mycreds = New-Object System.Management.Automation.PSCredential ($userid, $password)
Connect-PIServer -vCA -Credential $mycreds -WarningAction 0 -ErrorAction 0
$regionstar = $region + "*"
Write-Host $regionstar                      
Get-PIComputeInstance -Region $regionstar | Connect-PIComputeInstance -WarningAction 0 -ErrorAction 0
Import-CIVAppTemplate -SourcePath "C:\Damn Small Linux\Damn Small Linux.ovf" -Name DamnSmallLinuxTemplate -OrgVdc $myOrgvdc -Catalog $myCatalog