#!/usr/bin/env python

import time, re, os, json, sys, optparse, ConfigParser
from pyvcloud.vcloudair import VCA

SERVICE_MAP         = {'vca': 'ondemand', 'vchs': 'subscription', 'vcd': 'vcd'}


class VCAInventory(object):

    def __init__(self):
        self.user           = None
        self.password       = None
        self.version        = None
        self.host           = None
        self.verify         = None

        self.results = {}
        self.meta    = dict(hostvars={})

        self.config = ConfigParser.SafeConfigParser()
        if os.environ.get('VCA_INI', ''):
            config_files = [os.environ['VCA_INI']]
        else:
            config_files =  [os.path.abspath(sys.argv[0]).rstrip('.py') + '.ini', 'vca.ini']
        for config_file in config_files:
            if os.path.exists(config_file):
                self.config.read(config_file)
                break
        
        self.user = os.environ.get('VCA_USER')
        if not self.user and self.config.has_option('auth', 'user'):
            self.user = self.config.get('auth', 'user')
        self.password = os.environ.get('VCA_PASS')
        if not self.password and self.config.has_option('auth', 'password'):
            self.password = self.config.get('auth', 'password')
        if self.config.has_option('auth', 'service_type'):
            service_type_temp = self.config.get('auth', 'service_type') 
            self.service_type = SERVICE_MAP[service_type_temp]
        if not self.config.has_option('auth', 'service_type'):
            self.service_type = 'vca'
        if self.config.has_option('auth', 'api_version'):
            self.version = self.config.get('auth', 'api_version') 
        if not self.config.has_option('auth', 'api_version'):
            self.version = '5.7'
        if self.config.has_option('auth', 'verify'):
            self.verify = self.config.get('auth', 'verify') 
        if not self.config.has_option('auth', 'verify'):
            self.verify = True
        if self.service_type == 'ondemand':
            self.host = 'vca.vmware.com'
        if self.service_type == 'subscription':
            self.host = 'vchs.vmware.com'
            self.version = '5.6'
        
        if not self.config.has_option('defaults', 'set_ssh_host'):
            self.set_ssh_host = True
        else:
            self.set_ssh_host = self.config.get('defaults', 'set_ssh_host')
        if self.service_type == 'vcd':
            if not self.config.has_option('auth', 'host'):
                sys.stdout.write("host config is needed when serivice type is vcd")
                sys.exit(1)
            self.host = self.config.get('auth', 'host') 
            if not self.config.has_option('auth', 'org'):
                sys.stdout.write("org config is needed when serivice type is vcd")
                sys.exit(1)
            self.org = self.config.get('auth', 'org')

        if self.verify in ['true', 'True', 'yes', 'Yes']:
            self.verify = True
        else:
            self.verify = False

        self.vca = VCA(host=self.host, username=self.user, service_type=self.service_type,\
                       version=self.version, verify=self.verify)
    
    def _put_cache(self, name, value):
        if self.config.has_option('defaults', 'cache_dir'):
            cache_dir = self.config.get('defaults', 'cache_dir')
            if not os.path.exists(os.path.expanduser(cache_dir)):
                os.makedirs(os.path.expanduser(cache_dir))
            cache_file = os.path.join(cache_dir, name)
            with open(cache_file, 'w') as cache:
                json.dump(value, cache) 
            cache.close()

    def _get_cache(self, name, default=None):
        if self.config.has_option('defaults', 'cache_dir'):
            cache_dir = self.config.get('defaults', 'cache_dir')
            cache_file = os.path.join(cache_dir, name)
            if os.path.exists(cache_file):
                if self.config.has_option('defaults', 'cache_max_age'):
                    cache_max_age = self.config.getint('defaults', 'cache_max_age')
                else:
                    cache_max_age = 0
                cache_stat = os.stat(cache_file)
                if (cache_stat.st_mtime + cache_max_age) < time.time():
                    with open(cache_file) as cache:
                        return json.load(cache)
        return default
   
    def to_safe(self, word):
        return re.sub("[^A-Za-z0-9\_]", "_", word)

    def vm_details(self, vm_name=None, vapp=None):
        table = {}
        networks = []
        vms = filter(lambda vm: vm['name'] == vm_name, vapp.get_vms_details())
        networks = vapp.get_vms_network_info()
        if len(networks[0]) > 0:
            table.update(vms[0]) 
            table.update(networks[0][0])
            if 'ip' in networks[0][0] and self.set_ssh_host:
                table['ansible_ssh_host'] = networks[0][0]['ip']
        else:
            table.update(vms[0]) 
            table.update(networks[0])
        return table
    
    
    def get_vdcs(self, vca=None):
        links = vca.vcloud_session.organization.Link if vca.vcloud_session.organization else []
        vdcs = filter(lambda info: info.type_ == 'application/vnd.vmware.vcloud.vdc+xml', links)
        return vdcs
    
    def get_vapps(self, vca=None, vdc_name=None):
        table1 = []
        the_vdc = vca.get_vdc(vdc_name)
        if the_vdc:
            table1 = []
            for entity in the_vdc.get_ResourceEntities().ResourceEntity:
                if entity.type_ == 'application/vnd.vmware.vcloud.vApp+xml':
                    the_vapp = vca.get_vapp(the_vdc, entity.name)
                    vms = []
                    if the_vapp and the_vapp.me.Children:
                        for vm in the_vapp.me.Children.Vm:
                            vms.append(vm.name)
                            hostvars = self.vm_details(vm.name, the_vapp)
                            self.meta['hostvars'][vm.name] = hostvars
                    table1.append(dict(vapp_name=vdc_name + '_' + entity.name, vms=vms, status=the_vapp.me.get_status(),\
                                   Deployed= 'yes' if the_vapp.me.deployed else 'no', desciption = the_vapp.me.Description)) 
        return table1
    
    def get_inventory_vcd(self):
        if not self.vca.login(password=self.password, org=self.org):
            sys.stdout.write("Login Failed: Please check username or password or your api version")
        if not self.vca.login(token=self.vca.token, org=self.org, org_url=self.vca.vcloud_session.org_url):
            sys.stdout.write("Failed to login to org")
	vdcs = self.get_vdcs(self.vca)
        org_children = []
	for j in vdcs:
            actual_vdc = j.name
            j.name = self.to_safe(j.name)
	    self.results[j.name] = dict(children=[])
	    org_children.append(j.name)
	    vapps = self.get_vapps(self.vca, j.name) 
	    for k in vapps:
                k['vapp_name'] = self.to_safe(k['vapp_name'])
	        self.results[j.name]['children'].append(k['vapp_name'])
	        self.results[k['vapp_name']] = k['vms']
	self.results[self.org] = dict(children=org_children)
	self.results['_meta'] = self.meta
        cache_name = '__inventory_all__' + self.service_type
        self._put_cache(cache_name, self.results)
        return self.results

    def get_inventory_vca(self):

        if not self.vca.login(password=self.password):
            sys.stdout.write("Login Failed: Please check username or password")
            sys.exit(1)
	instances_dict = self.vca.get_instances()
	for i in instances_dict:
	    instance = i['id']
#	    region   = i['id']
	    region   = i['region']
            region   = self.to_safe(region.split('.')[0])
	    region_children = []
	    if len(instance) != 36:
	        continue
	    if not self.vca.login_to_instance(password=self.password, instance=instance, token=None, org_url=None):
	        sys.stdout.write( "Login to Instance failed: Seems like instance provided is wrong .. Please check")
	        sys.exit(1)
	    if not self.vca.login_to_instance(instance=instance, password=None, token=self.vca.vcloud_session.token, 
	                                 org_url=self.vca.vcloud_session.org_url):
	        sys.stdout.write("Error logging into org for the instance %s" %instance)
	    vdcs = self.get_vdcs(self.vca)
	    for j in vdcs:
                j.name = self.to_safe(j.name)
	        self.results[region + '_' + j.name] = dict(children=[])
	        region_children.append(region + '_' + j.name)
	        vapps = self.get_vapps(self.vca, j.name) 
	        for k in vapps:
                    k['vapp_name'] = self.to_safe(k['vapp_name'])
	            self.results[region + '_' + j.name]['children'].append(region + '_' + j.name + '_' + k['vapp_name'])
	            self.results[region + '_' + j.name + '_' + k['vapp_name']] = k['vms']
	    self.results[region] = dict(children=region_children)
	
	self.results['_meta'] = self.meta
        cache_name = '__inventory_all__' + self.service_type
        self._put_cache(cache_name, self.results)
        return self.results
    
    def get_inventory_vchs(self):
        
        if not self.vca.login(password=self.password):
            sys.stdout.write("Login Failed: Please check username or password, errors: %s" %(self.vca.response))
            sys.exit(1)
        
        if not self.vca.login(token=self.vca.token):
            sys.stdout.write("Failed to get the token")
            sys.exit(1)

        if self.vca.services:
            table = []
            for s in self.vca.services.get_Service():
                for vdc in self.vca.get_vdc_references(s.serviceId):
                    table.append(dict(service=s.serviceId, service_type=s.serviceType, region=s.region,\
                                      vdc=vdc.name, status=vdc.status))  
            for i in table:
                if i['service'] != i['vdc']:
                    self.results[i['service']] = dict(children=[i['vdc']])
                region = i['vdc']
                region = self.to_safe(region)
                self.results[region] = dict(children=[])
                if not self.vca.login_to_org(i['service'], i['vdc']):
                    sys.stdout.write("Failed to login to org, Please check the orgname")
	        vapps = self.get_vapps(self.vca, i['vdc']) 
	        for k in vapps:
                    k['vapp_name'] = self.to_safe(k['vapp_name'])
	            self.results[region]['children'].append(region + '_' + k['vapp_name'])
	            self.results[region + '_' + k['vapp_name']] = k['vms']

	self.results['_meta'] = self.meta
        cache_name = '__inventory_all__' + self.service_type
        self._put_cache(cache_name, self.results)
        return self.results
	

    def get_inventory(self):
        cache_name = '__inventory_all__' + self.service_type
        inv = self._get_cache(cache_name, None)
        if inv is not None:
            return inv
        if self.service_type == 'ondemand':
            return self.get_inventory_vca()
        if self.service_type == 'subscription':
            return self.get_inventory_vchs()
        if self.service_type == 'vcd':
            return self.get_inventory_vcd()

def main():
    parser = optparse.OptionParser()
    parser.add_option('--list', action='store_true', dest='list',
                           default=False, help='Output inventory groups and hosts')
    parser.add_option('--host', dest='host', default=None, metavar='HOST',
                            help='Output variables only for the given hostname')
    options, args = parser.parse_args()
    inventory = VCAInventory()
    res = inventory.get_inventory()
    json_kwargs = {}
    json_kwargs.update({'indent': 4, 'sort_keys': True})
    json.dump(res, sys.stdout, **json_kwargs)


if __name__ == '__main__':
        main()
