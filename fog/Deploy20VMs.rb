##################################################################
####             This program instantiates "n" VMs           #####
####   in a vCloud Air and/or vCloud Director environment    #####
####            it leverages the fog cloud library           #####
##################################################################

require 'awesome_print'
require 'fog'

##################################################################
####             IMPORTANT : start of user inputs            #####
##################################################################
inputvdc = "VDC1"
inputcatalog = "Public Catalog"
inputtemplate = 'CentOS64-64BIT'
inputnetwork = "DMZ"
inputvappname = "webserver"
numberofvms = 20
username = "your-user@your-org"
password = "your-password" 
host = "your-FQDN-vCD-endpoint"
#apipath = "/api/compute/api" #uncomment this line if you are using the VCA platform
#apipath = "/api" #uncomment this line if you are using the VCHS platform or vCD standalone
# how do I know if I am using the VCA or VCHS platform? 
# see https://github.com/mreferre/vcautils#Technical-Background 
##################################################################
####                      end of user inputs                 #####
##################################################################



##################################################################
####              vca stack connection example               #####
##################################################################
#username = "john@company.com@f607ff03-ddfe-4d6d-b7cc-2cb16c3459c7"
#password = "password" 
#host = "au-south-1-15.vchs.vmware.com"
#apipath = "/api/compute/api"
##################################################################

##################################################################
####              vchs stack connection example              #####
##################################################################
#username = "john@company.com@M592554335-4865"
#password = "password" 
#host = "p6v1-vcd.vchs.vmware.com"
#apipath = "/api"
##################################################################

##################################################################
####            vcd standalone connection example            #####
##################################################################
#username = "massimo@it20"
#password = "password" 
#host = "mycloud.cloudprovider.com"
#apipath = "/api"
##################################################################



# create a connection to vCD
vcloud = Fog::Compute::VcloudDirector.new(
  :vcloud_director_username => username,
  :vcloud_director_password => password,
  :vcloud_director_host => host,
  :path=> apipath, 
  :vcloud_director_show_progress => true, # task progress bar on/off
)

# select the org (there will be one as a "tenant") 
org = vcloud.organizations.first
ap org

# select a vdc by name
vdc = org.vdcs.get_by_name(inputvdc)
ap vdc

# select a catalog by name
catalog = org.catalogs.get_by_name(inputcatalog)
ap catalog 

# select a template by name
template = catalog.catalog_items.get_by_name(inputtemplate)
ap template

# select a network by name (note that if there are multiple networks with the same name in multiple VDC it won't work) 
# right now it will query the Org for the network and if there are more with the same name it will pick one 
network = org.networks.get_by_name(inputnetwork)
ap network

# start the cycle to deploy "n" VMs (according to the "numberofvms" variable set at the top)
i = 0 
while i < numberofvms do 

  # set unique vapp name to "inputvappname" + counter 
  vappname = inputvappname + i.to_s
  puts "Now instantiating " + vappname 

  # instantiate a vApp from the vApp template and deploy in given VDC and to given network
  template.instantiate(vappname, {
    vdc_id: vdc.id,
    network_id: network.id
  })

  # select the VM (we assume there is one VM per vApp)
  vapp = vdc.vapps.get_by_name(vappname)
  vm = vapp.vms.first
  ap vm 

  # change the VM name and set it to be = to the vApp name
  # this is somewhat of an hack
  # ideally one should be able to set the name with the fog model (to be implemented)
  # see: https://github.com/fog/fog/issues/2761
  vm_id = vm.id
  vcloud.put_vm(vm_id, vappname, {})
  ap vm

  # wait_for doesn't seem to be working so we just sleep 10 secs 
  # vm.wait_for(30) { ready? }
  sleep(20)

  # connect the VM to the vApp Network we created during the vApp instantiation
  vmnetwork = vm.network
  ap vmnetwork
  vmnetwork.network = inputnetwork
  vmnetwork.is_connected = true
  vmnetwork.ip_address_allocation_mode = "POOL"
  vmnetwork.save

  vapp.power_on
  i += 1
end 