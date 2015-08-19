
#!/bin/bash

# This script illustrates how to login to vCloud Air, create a VM and expose it to the internet on a public IP.
# It configures the vCloud Air gateway and creates and customizes the VM to allow the root user to loging using ssh without a password.

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



# Create a new VM based on the CentOS template in the vCloud Air Public Catalog  
# Modify to set a your own values for VAPP_NAME and VM_NAME.
# VMs will be placed on the default-routed-network with IPs allocated from the Gateway static pool
# Refer to the xyz example to see how to customize a VM with a set password or ssh key for root.
export VAPP_NAME='myVappName'
export VM_NAME='myVmName'
# Set an existing public IP value if you have one, otherwise the script will add a new public ip to the gateway
export PUBLIC_IP='107.189.113.86'

vca vapp create -a $VAPP_NAME -V $VM_NAME -c 'Public Catalog' -t CentOS64-64BIT -n default-routed-network -m pool    

# Get the internal IP of the new VM
IP=`vca -j vm -a $VAPP_NAME | jq --raw-output '.vms[0].IPs'` && echo $IP


# Generate a new rsa key for the root user since that user exists
export NEW_USER=root

#ssh-keygen -f ${NEW_USER}_rsa -P ""
export key_file=${NEW_USER}_rsa.pub
export key=$(<${key_file})
sed "s/--KEY-HERE--/$(sed 's:/:\\/:g' ${key_file})/g" ./add_public_ssh_key_centos.txt > ./add_public_ssh_key_centos.sh


# Customize the VM
vca vapp customize --vapp $VAPP_NAME --vm $VM_NAME --file ./add_public_ssh_key_centos.sh

  

# If a public IP is not defined, 
# Add a public IP to the VDC Gateway for the new VM
if [ -z ${PUBLIC_IP+x} ]; then
   vca gateway add-ip

   # Get the newly added public IP
   PUBLIC_IP=`vca -j gateway info | jq --raw-output '.gateway[] | select(.Property=="External IPs").Value | split(", ") |.[length - 1]'` && echo $PUBLIC_IP
fi

# Add a SNAT rule for the Network if it does not already exist
export SNAT_RULE=$(vca -j nat  | jq --arg public_ip "$PUBLIC_IP" '."nat-rules"[] | select(."Translated IP"==$public_ip) | select(.Type=="SNAT")')
if [ ! "${SNAT_RULE}" ]; then
   
   vca nat add --type SNAT --original-ip 192.168.109.0/24 --translated-ip $PUBLIC_IP
fi

# Add a DNAT rule for the public ip -> ip mapping if it does not already exist
export DNAT_RULE=$(vca -j nat  | jq --arg public_ip "$PUBLIC_IP" '."nat-rules"[] | select(."Translated IP"==$public_ip) | select(.Type=="DNAT")')
if [ ! "${DNAT_RULE}" ]; then 
  vca nat add --type DNAT --original-ip $PUBLIC_IP --original-port 22 --translated-ip $IP --translated-port 22 --protocol tcp
fi

# Disable the firewall
vca firewall disable

# Test the login, login and run a command
ssh -i ./${NEW_USER}_rsa  ${NEW_USER}@${PUBLIC_IP} echo "Successfully Logged into  $(hostname)"


# end session
vca logout

                               