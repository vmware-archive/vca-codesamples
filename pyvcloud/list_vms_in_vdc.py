#
# This example lists all the VMs in a VDC. 
# vCloud Air account credentials should be supplied using environment variables VCA_USER nad VCA_PASS
# All other Input values are supplied by a configuration file passed in as an input parameter
# For example
# python list_vms_in_vdc.py config_ondemand.yaml
#

import time, datetime, os, sys, getopt
from pyvcloud.vcloudair import VCA
import yaml
import logging
import operator


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
       
        
     


def _as_list(input_array):
    return str(input_array).strip('[]').replace("'", "")


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

   # List all vms in the current VDC

   table1 = []
   for entity in the_vdc.get_ResourceEntities().ResourceEntity:
          if entity.type_ == 'application/vnd.vmware.vcloud.vApp+xml':
              the_vapp = vca.get_vapp(the_vdc, entity.name)
              vms = []
              if the_vapp and the_vapp.me.Children:
                  for vm in the_vapp.me.Children.Vm:
                      vms.append(vm.name)
              table1.append(_as_list(vms))
   table = sorted(table1, key=operator.itemgetter(0), reverse=False)

   print "VMs in VDC " + vdc_name
   print table
  

   # 
   # Logout of vCloud Air 
   #
   vca.logout()


if __name__ == "__main__":
   main(sys.argv[1:])
