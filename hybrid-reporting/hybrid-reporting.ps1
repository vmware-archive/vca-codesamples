#This script connects to one vCenter server (hard coded) and prompts for user and password
#It also connects to vCloud Air OnDemand by prompting for your vCloud Air user and password
#The script will then prompt for which OnDemand instance(s) you want to gather information from
 
#Connect to vSphere
Connect-VIServer vc-01a.corp.local -User Administrator@vsphere.local -Password VMware1!

#Connect to vCloud Air and select instance(s)
Connect-PIServer -vca
$CI = Get-PIComputeInstance | Out-GridView -OutputMode Multiple
$CI | Connect-CIServer
#$CI = Get-PIComputeInstance -Region *cali* | Where { $_.ServiceGroup -match “M787177008" }
#$CI | Connect-CIServer

# List all vSphere VMs with specific properties
$vSphereVM = Get-VM | Select Name, PowerState, MemoryGB, NumCPU, @{Name="GuestOsFullName";Expression={$_.extensiondata.guest.GuestFullName}}, @{Name="Location";Expression={($_ | Get-Cluster).Name}}, @{Name="Platform";Expression={"vSphere: $(($global:DefaultVIServer).Name)"}}

# List all vCloud Air VMs with specific properties
$vCAVM = Get-CIVM | Select Name, @{Name="PowerState";Expression={$_.status}}, MemoryGB, @{Name="NumCpu";Expression={$_.CPUCount}}, GuestOSFullName, @{Name="Location";Expression={$_.OrgVDC}},@{Name="Platform";Expression={"vCloud Air: $($CI.Region)"}}

# Create a blank array
$AllVMs = @()

# Add our vSphere VMs to the array
$AllVMs += $vSphereVM
# Add our vCloud Air VMs to the array
$AllVMs += $vCAVM

# Show the results on the screen in a table
$AllVMs | Format-Table -AutoSize

# Export the contents to a CSV File
$AllVMs | Export-Csv -NoTypeInformation -Path c:\temp\HybridReport.csv

