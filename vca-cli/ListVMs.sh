#!/bin/bash

# This script illustrates how to login to vCloud Air and list the VMs in a VDC.
# You must modify the script to set your local values before use.
# Use only one of the login commands below depending on the service type you are connecting to, comment out the other login line.
# This script has been tested using vca-cli version (vcacli_14)

# Fail this script on command error
set -e

# Don’t forget to set VCA_USER as an environment variable or login will fail
# For example:  export VCA_USER='user@example.com'
if [ -z ${VCA_USER+x} ]; then echo “Error: you must set the environment variable VCA_USER to your vca account username”;
    exit 1
fi  

# Don’t forget to set VCA_PASS as an environment variable or login will fail
# For example:  export VCA_PASS='mypassword!'
if [ -z ${VCA_PASS+x} ]; then echo “Error: you must set the environment variable VCA_PASS to your vca account password”;
    exit 1
fi


# Login to an onDemand service instance
# Modify to use your vcloud Air username, password, instance and vdc.
# Instance and vdc values are available on the vCloud Air Portal after login.
vca login ${VCA_USER}   --password  ${VCA_PASS}   --instance 97453e02-e83c-4cae-bbe9-3f7ee6dd8401 --vdc VDC1 

# Login to a Subscription service instance
# Modify to use your vcloud Air username, password, org and instance.
# Instance and vdc values are available on the vCloud Air Portal after login.
#vca login ${VCA_USER}   --password ${VCA_PASS}   --host vchs.vmware.com   --version 5.6 --org M933009684-9999  --instance M933009684-9999 



# List all VMs in the VDC

vca vm list

# end session

vca logout