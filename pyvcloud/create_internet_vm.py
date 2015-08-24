#
# This example uses the pyvcloud API to create a vApp and connect it to the internet
# vCloud Air account credentials should be supplied using environment variables VCA_USER nad VCA_PASS
# All other Input values are supplied by a configuration file passed in as an input parameter
# For example
# python create_internet_vm.py config.yaml
#

import time, datetime, os, sys, getopt
from pyvcloud.vcloudair import VCA
import yaml
import logging


def print_vca(vca):
    if vca:
        print 'vca token:            ', vca.token
        if vca.vcloud_session:
            print 'vcloud session token: ', vca.vcloud_session.token
            print 'org name:             ', vca.vcloud_session.org
            print 'org url:              ', vca.vcloud_session.org_url
            print 'organization:         ', vca.vcloud_session.organization
        else:
            print 'vca vcloud session:   ', vca.vcloud_session
    else:
        print 'vca: ', vca

def log_level(x):
    return {
        'CRITICAL': 50, 'ERROR': 40, 'WARNING': 30,
        'INFO': 20, 'DEBUG': 10, 'NOTSET': 0,
    }.get(x, 40)


def login_to_vcloud(username, password, host, version, org, service_type, instance):       

        vca = VCA(host=host, username=username, service_type=service_type, version=version, verify=True, log=True)
        assert vca

        if VCA.VCA_SERVICE_TYPE_STANDALONE == service_type:
            result = vca.login(password=password, org=org)
            assert result, "Wrong password or Org?"
            result = vca.login(token=vca.token, org=org, org_url=vca.vcloud_session.org_url)
            assert result
        elif VCA.VCA_SERVICE_TYPE_VCHS == service_type:
            result = vca.login(password=password)
            assert result, "Wrong Password?"
            result = vca.login(token=vca.token)
            assert result
            result = vca.login_to_org(instance, org)  # service now called instance
            assert result, "Wrong service/aka instance or org?"
        elif VCA.VCA_SERVICE_TYPE_VCA == service_type:
            result = vca.login(password=password)
            assert result
            result = vca.login_to_instance(password=password, instance=instance, token=None, org_url=None)
            assert result
            print "token " + vca.vcloud_session.token
            result = vca.login_to_instance(password=None, instance=instance, token=vca.vcloud_session.token, org_url=vca.vcloud_session.org_url)
            assert result

        return vca
       
        
      

def power_on(vca, vdc_name, vapp_name):
       
        the_vdc = vca.get_vdc(vdc_name)
        the_vapp = vca.get_vapp(the_vdc, vapp_name)
        assert the_vapp
        assert the_vapp.name == vapp_name
        if(the_vapp.me.get_status() == 4):
            print ("vApp " + vapp_name + " is already powered on, skipping power on request.")
        else:
            task = the_vapp.poweron()
            assert task
            print ("Powering on vApp")
            result = vca.block_until_completed(task)
            assert result
            the_vapp = vca.get_vapp(the_vdc, vapp_name)
            assert the_vapp != None
            assert the_vapp.me.get_status() == 4, "vApp is not powered on"
            print("vApp powered on.")


def connect_to_network(vca, vdc_name, vapp_name, network, mode):
 
        nets = filter(lambda n: n.name == network, vca.get_networks(vdc_name))
        assert len(nets) == 1
        the_vdc = vca.get_vdc(vdc_name)
        the_vapp = vca.get_vapp(the_vdc, vapp_name)
        assert the_vapp
        assert the_vapp.name == vapp_name

        # Connect vApp
        print ("Attaching vApp to network.")
        task = the_vapp.connect_to_network(nets[0].name, nets[0].href)
        result = vca.block_until_completed(task)
        print ("Connected.")
        assert result      

        # Connect VM
        print ("Attaching vm to network.")
        if(mode == 'pool'):
            task = the_vapp.connect_vms(nets[0].name, connection_index=0, ip_allocation_mode='POOL')
        else:
            if(mode == 'dhcp'):
                task = the_vapp.connect_vms(nets[0].name, connection_index=0, ip_allocation_mode='DHCP')

        assert task
        result = vca.block_until_completed(task)
        assert result      
        print ("Connected.")



def check_duplicate_rule(vca, vdc_name, gateway_name, rule_type, original_ip, original_port, translated_ip, translated_port, protocol):

        the_gateway = vca.get_gateway(vdc_name, gateway_name)
        assert the_gateway
        assert the_gateway.get_name() == gateway_name

        nat_rules = the_gateway.get_nat_rules()
        found_rule = False
        for natRule in nat_rules:
            ruleId = natRule.get_Id()
            if rule_type == natRule.get_RuleType():
                gatewayNatRule = natRule.get_GatewayNatRule()
                
                gateway_original_ip = gatewayNatRule.get_OriginalIp() if gatewayNatRule.get_OriginalIp() else 'any'
                gateway_original_port = gatewayNatRule.get_OriginalPort() if gatewayNatRule.get_OriginalPort() else 'any'
                gateway_translated_ip = gatewayNatRule.get_TranslatedIp() if gatewayNatRule.get_TranslatedIp() else 'any'
                gateway_translated_port = gatewayNatRule.get_TranslatedPort() if gatewayNatRule.get_TranslatedPort() else 'any'
                gateway_protocol = gatewayNatRule.get_Protocol() if gatewayNatRule.get_Protocol() else 'any'
          
                if original_ip == gateway_original_ip and \
                   original_port == gateway_original_port and \
                   translated_ip == gateway_translated_ip and \
                   translated_port == gateway_translated_port and \
                   protocol == gateway_protocol:
                    found_rule = True
       
        return found_rule


#########################################################
### Create a vApp and configure it for Internet Access 
#########################################################

def main(argv):

   if(len(sys.argv) != 2):
      print 'Please supply an input configuration file.'
      print 'Usage: ' + sys.argv[0]  + ' <configFile>'
      sys.exit(2)

   try:
      config = open(sys.argv[1], "r")
   except IOError:
      print "Error: File " + sys.argv[1] + " does not appear to exist."
      return 2

   config = yaml.load(config)

   service_type = config['vcloud']['service_type']
   instance = config['vcloud']['instance']

   host = config['vcloud']['host']
   version = config['vcloud']['version']
   org = config['vcloud']['org']
   vdc_name = config['vcloud']['vdc_name']
   vapp_name  = config['vcloud']['vapp_name'] 
   vm_name  = config['vcloud']['vm_name'] 
   network_name  = config['vcloud']['network_name']
   network_mode = config['vcloud']['network_mode']
   public_ip = config['vcloud']['public_ip']
   template_name = config['vcloud']['template_name']
   catalog_name = config['vcloud']['catalog_name']
   vm_cpus =config['vcloud']['vm_cpus']
   vm_memory = config['vcloud']['vm_memory']

   LOG_FILENAME = config['pyvcloud']['logfile']
   LOG_LEVEL = config['pyvcloud']['loglevel']

   logging.basicConfig(filename=LOG_FILENAME, level=log_level(LOG_LEVEL))

   try:
       username = os.environ['VCA_USER']
   except KeyError, e:
       print ('Error: A VCAUSER environment variable must be set for login')
       sys.exit(2)

   try:
       password = os.environ['VCA_PASS']
   except KeyError, e:
      print ('Error: A PASSWORD environment variable must be set for login')
      sys.exit(2)


   #
   # Login
   #  
   vca = login_to_vcloud(username, password, host, version, org, service_type, instance)
  
   if vca.vcloud_session is None:
       print_vca(vca)
       print "Error: Login Failed, unable to create session."
       sys.exit(2)

   the_vdc = vca.get_vdc(vdc_name)
   assert the_vdc, "Error: Unable to connect to VDC " + vdc_name

   
   #
   # Create a new vApp
   #

   # First check if it exists
   the_vdc = vca.get_vdc(vdc_name)
   if(vca.get_vapp(the_vdc, vapp_name) != None):
       print ("vApp " + vapp_name + " already exists, skipping creation request")
   else:
       task = vca.create_vapp(vdc_name, vapp_name, template_name, catalog_name, \
                          network_name, network_mode, vm_name, vm_cpus, vm_memory, \
                          deploy='false', poweron='false') 
       assert task, "Error creating vApp, check the file " + LOG_FILENAME + " for details."

       print "Waiting for vApp creation to complete."
       result = vca.block_until_completed(task)
       assert result

       # Get the vdc again
       the_vdc = vca.get_vdc(vdc_name)
       assert the_vdc, "Error: Unable to connect to VDC " + vdc_name

       the_vapp = vca.get_vapp(the_vdc, vapp_name)
       assert the_vapp
       assert the_vapp.name == vapp_name

       print "Created vAPP " + the_vapp.name

   #
   # Connect vApp and VM to network
   #
   connect_to_network(vca, vdc_name, vapp_name, network_name, network_mode)

   #
   # Get the IP of the VM
   #
   the_vapp = vca.get_vapp(the_vdc, vapp_name)
   vm_info = the_vapp.get_vms_network_info()
   print vm_info
   vm_ip = vm_info[0][0].get("ip")
   print "VM using IP " + vm_ip
  

   # Add DNAT rule for VM
   # First, check for existing DNAT rule
   if(check_duplicate_rule(vca, vdc_name, 'gateway', 'DNAT', public_ip, "33", vm_ip, "22", 'tcp')):
       print "DNAT rule exists, using existing rule."
   else:
       the_gateway = vca.get_gateway(the_vdc.get_name(), 'gateway')
       assert the_gateway
       
       the_gateway.add_nat_rule('DNAT', public_ip, "33", vm_ip, "22",  'tcp') # apply to gateway network xxx-ext
       task = the_gateway.save_services_configuration()
       assert task
       print "Adding DNAT rule to enable vm remote access " + vm_ip
       result = vca.block_until_completed(task)
       assert result
       print "Rule Added"


   # Add a SNAT rule if one does not exist

   if(check_duplicate_rule(vca, vdc_name, 'gateway', 'SNAT', "192.168.109.0/24", "any", public_ip, "any", "any")):
       print "SNAT rule exists, using existing rule."
   else:
       the_gateway = vca.get_gateway(the_vdc.get_name(), 'gateway')
       assert the_gateway
       
       the_gateway.add_nat_rule('SNAT', "192.168.109.0/24", "any", public_ip, "any",  'any') # apply to gateway network xxx-ext
       task = the_gateway.save_services_configuration()
       assert task
       print "Adding DNAT rule to enable vm remote access " + vm_ip
       result = vca.block_until_completed(task)
       assert result
       print "Rule Added"

   # Disable the firewall
   print "Diabling firewall for test"
   the_gateway = vca.get_gateway(the_vdc.get_name(), 'gateway')
   the_gateway.enable_fw(False)

   #
   # Power on the vApp
   #
   power_on(vca, vdc_name, vapp_name)
    
   vm_details = the_vapp.get_vms_details()
   print vm_details
   vm_admin_password = vm_details[0].get("admin_password")
   print "VM Ready, Login using ssh root@" + public_ip + " -p33     using password " + vm_admin_password

   # 
   # Logout of vCloud Air 
   #
   vca.logout()


if __name__ == "__main__":
   main(sys.argv[1:])
