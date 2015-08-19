
#!/bin/bash

# This script illustrates how to login to vCloud Air and create 20 VM instances.
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



# Create 20 instances of a VM based on the CentOS template in the vCloud Air Public Catalog  
# Modify to set a your own values for VAPP_NAME and VM_NAME.
# VApps created with be named myVappName-1, myVappName-2 etc
# VMs will be placed on the default-routed-network with IPs allocated from the Gateway static pool
# Login passwords for root will be auto generated and visible in the vCloud Air Portal
# Refer to the xyz example to see how to customize a VM with a set password or ssh key for root.
VAPP_NAME = 'myVappName'
VM_NAME = 'myVmName'
COUNT = 2
vca vapp create -a $VAPP_NAME -V $VM_NAME -c 'Public Catalog' -t CentOS64-64BIT -n default-routed-network -m pool --count $COUNT    


# Optional:
# Get and save the IP for each new VM created for later use
# export variables in the form   myVappName_1_IP=192.168.0.1
# Uses the jq parser utlity - https://stedolan.github.io/jq/ 

VMS=$(vca -j vm)
for (( c=1; c<=${COUNT}; c++ ))
do
 export VA_NAME=${VAPP_NAME}-${c}
 VA_IP=`echo $VMS | jq --raw-output --arg va_name "$VA_NAME" '.vms[] | select(.vApp==$va_name).IPs'` 
 #Remove any - characters, not valid in export variable name
 VA_NAME="${VA_NAME//-/_}"
 export ${VA_NAME}_IP=$VA_IP;  echo $VA_NAME $VA_IP
done


# end session

vca logout

                               