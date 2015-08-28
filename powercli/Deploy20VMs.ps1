# This script deploys <n> vApps from a template as separate jobs
# Reads as inputs User, Password, Region, VDC and number of vApps to deploy
# Hard coded: Network and Template name 

$userid = Read-Host 'Enter userid'
$password = Read-Host 'Enter password' -AsSecureString
$region = Read-Host 'Enter the Region you want to deploy to [e.g. us-ca, us-vi, uk-sl, au-so, de-ge]' 
$myOrgVdc = Read-Host 'Enter the OrgVdc you want to deploy to'
$number = Read-Host 'Enter how many templates you want to deploy'

1..$number | Foreach {

  Start-Job -ScriptBlock {  
                            $WarningPreference = "SilentlyContinue"
                            import-module vmware.vimautomation.cloud
                            import-module vmware.vimautomation.pcloud
                            $mycreds = New-Object System.Management.Automation.PSCredential ($args[2], $args[3])
                            Connect-PIServer -vCA -Credential $mycreds -WarningAction 0 -ErrorAction 0
                            $regionstar = $args[0] + "*"
                            Write-Host $regionstar                      
                            Get-PIComputeInstance -Region $regionstar | Connect-PIComputeInstance -WarningAction 0 -ErrorAction 0
                            $random = Get-Random -minimum 1 -maximum 9999
                            $Name = "PowerCLITest" + $random
                            $myTemplate = 'CentOS64-64BIT'
                            $myOrgNetwork = 'default-routed-network'
                            $myOrgVdc = Get-OrgVdc -name $args[1]
                            $myOrgNetworkConsistent = Get-OrgNetwork -Id (Search-Cloud -QueryType OrgVdcNetwork -Filter "VdcName==$myOrgVdc;Name==$myOrgNetwork").Id
                            Write-Host 
                            Write-Host $Name
                            Write-Host $myTemplate
                            Write-Host $myOrgVdc
                            Write-Host $myOrgNetworkConsistent
                            $NewvApp = New-CIVApp -Name $Name -OrgvDC $myOrgVdc -VAppTemplate $myTemplate
                            $NewVAppNetwork = New-CIVAppNetwork -VApp $Name -Direct -ParentOrgNetwork $myOrgNetworkConsistent
                            Get-CIVApp -Name $Name | Get-CIVM | Get-CINetworkAdapter | Set-CINetworkAdapter -IPAddressAllocationMode Pool -VAppNetwork $NewVAppNetwork -Connected:$true                            
                            Start-CIVApp -VApp $NewvApp
                         } -ArgumentList $region, $myOrgVdc, $userid, $password
}