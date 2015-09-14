#

### Topics covered

* Inventory
* Creating a playbook.
* Using vars
* Using with_items

### General flow

Configuring systems with ad-hoc tasks can be annoying -- and ad-hoc tasks don't really keep a good record of how a system ***should*** be configured.

In this example, we show how to use a simple playbook to setup a web application
on a vCA host.

### Reverse Engineer

Please create the following variables inside of site.yml before running the cmd

HINT: Look at the playbook to determine the name of the variable to create
the list. An example variable has been provided in the vars list. 

Instance ID: '0172af06-219a-4fcc-82f9-61728d639302'
Admin password: 'Provided at event'
Public IP: 'Provided at table'
vdc: 'Provided at table'
Template: "CentOS64-64BIT"
Catalog: "Public Catalog"
Network: "default-routed-network"
VMname: "VMdemo"
Network Mode: "pool"

### Commands

	ansible-playbook site.yml
