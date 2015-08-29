#!/bin/bash

### NEW VDC EXAMPLE
###
### This example demonstrates how to use vca-cli to create a new Virtual Data Center in an OnDemand Service instance
### Add and invite a new user to the VDC
### Add a VM and customize it so the new user can login without a password
### Configure the VDC Gateway to enable remote access to the VDC


# Before you run this script:

# Set your vcloud air username and password as environment variables VCA_USER and VCA_PASS

# Customize these Values Before executing the script
export INSTANCE=97453e02-e83c-4cae-bbe9-3f7ee6dd8401    # your on demand instance id
export INITIAL_VDC=VDC1                                 # An existing VDC to connect to
export NEW_VDC=DevOps-VDC                               # The name of the new VDC to be created
export NEW_VDC_USER_EMAIL=bob2@websterx.com             # The email of a new vcloud Air user who will be invited to join the VDC
export NEW_VDC_USER_FNAME=Bob                           # The first name of the new vcloud Air user who will be invited to join the VDC
export NEW_VDC_USER_LNAME=Webster                       # The last name of the new vcloud Air user who will be invited to join the VDC
export NEW_VAPP_NAME=bob1vapp                           # The name of the new Vapp that will be created in the new VDC
export NEW_VM_USER=bob1                                 # A new linux user that will be created on the VM and configured for ssh login


#
# vCloud Air vca-cli New VDC example
#

# Fail this script on command error
set -e

# Output the vca-cli version
vca -v

# Is VCA_USER set or login will fail
if [ -z ${VCA_USER+x} ]; then echo “set environment variable VCA_USER to your vca account username”;
fi	

# Is VCA_PASS set or login will fail
if [ -z ${VCA_PASS+x} ]; then echo “set environment variable VCA_PASS to your vca account password”;
fi


# onDemand Login
vca login $VCA_USER --password $VCA_PASS --instance $INSTANCE --vdc $INITIAL_VDC 

echo List available VDC creation templates
vca org list-templates

echo Create a new VDC…
vca vdc create --vdc $NEW_VDC --template d2p3v29-new-tp

echo Connect to the new VDC…
vca vdc use --vdc $NEW_VDC

# Show vca network
echo Show the VDC Gateway details...
#export UPLINK= $(vca gateway | vca -j gateway | jq --raw-output '.gateways[0].Uplinks')
#
vca gateway

# Show vca network
echo New networks available on the VDC…
vca network

# Create and assign new user to the new VDC
echo Invite a new user $VEW_VDC_USER_EMAIL to the VDC…
#vca user create --user $NEW_VDC_USER_EMAIL --first $NEW_VDC_USER_FNAME --last $NEW_VDC_USER_FNAME --roles 'Virtual Infrastructure Administrator'

# Show the user details
#echo New vCloud Air User Details…
#vca user | grep $NEW_VDC_USER_EMAIL

# List the available templates in the VDC catalog
echo List VM Templates from VDC Catalog…
vca catalog

# Create a new vAPP and VM running CentOS
echo Creating a new CentOS VM 
vca vapp create -a $NEW_VAPP_NAME -V myvm -c "Public Catalog" -t CentOS64-64BIT -n default-routed-network -m pool --cpu 2 --ram 2048

# Get the internal IP of the new VM

export IP=`vca -j vm -a $NEW_VAPP_NAME | jq --raw-output '.vms[0].IPs'` 
echo New VM ip is $IP

# Customize the VM with a new User and setup ssh access using keys

# Define the new user name
echo Customize the VM to have a new user named $NEW_VM_USER

# Generate a new rsa key for the user, answer y if prompted for overwrite
echo Generating a new RSA key pair for $NEW_VM_USER…
echo -e  'y\n'| ssh-keygen -q -t rsa  -N "" -f ${NEW_VM_USER}_rsa

export key_file=${NEW_VM_USER}_rsa.pub
export key=$(<${key_file})

# Generate a Customization File for the vm and include the key
echo '#!/bin/bash' > /tmp/customization.sh
echo "if [ x\$1=x\"postcustomization\" ];" >> /tmp/customization.sh
echo then >> /tmp/customization.sh
echo useradd -p \"*\" -U -m  ${NEW_VM_USER} -G wheel  >> /tmp/customization.sh
echo mkdir -p /home/${NEW_VM_USER}/.ssh >> /tmp/customization.sh
#echo echo \'${key}\’ \>\> /home/${NEW_VM_USER}/.ssh/authorized_keys >> /tmp/customization.sh
echo echo `more ${NEW_VM_USER}_rsa.pub` \>\> /home/${NEW_VM_USER}/.ssh/authorized_keys >> /tmp/customization.sh
echo chmod 700 /home/${NEW_VM_USER}/.ssh >> /tmp/customization.sh
echo chmod 600 /home/${NEW_VM_USER}/.ssh/authorized_keys >> /tmp/customization.sh
echo chown ${NEW_VM_USER} /home/${NEW_VM_USER}/.ssh >> /tmp/customization.sh
echo chown ${NEW_VM_USER} /home/${NEW_VM_USER}/.ssh/authorized_keys >> /tmp/customization.sh
echo restorecon /home/${NEW_VM_USER}/.ssh/authorized_keys >> /tmp/customization.sh
echo fi >> /tmp/customization.sh

# Customize the VM
echo Customize the VM to add the user and register the SSH key
vca vapp customize --vapp $NEW_VAPP_NAME --vm myvm --file /tmp/customization.sh

# Add a public IP to the VDC Gateway for the new VM
echo Add a new public IP to the VDC Gateway…
vca gateway add-ip

# Get the newly added public IP
PUBLIC_IP=`vca -j gateway info | jq --raw-output '.gateway[] | select(.Property=="External IPs").Value | split(", ") |.[length - 1]'` 
echo New gateway public ip is $PUBLIC_IP

# Add a SNAT rule for the Network if one does not exist
echo Adding Gateway SNAT Rule…
export SNAT_RULE=$(vca -j nat | jq --arg public_ip "$PUBLIC_IP" '."nat-rules"[] | select(."Translated IP"==$public_ip) | select(.Type=="SNAT")')
if [ ! "${SNAT_RULE}" ]; then
   vca nat add --type SNAT --original-ip 192.168.109.0/24 --translated-ip $PUBLIC_IP
fi


# Add a DNAT rule for the public ip -> ip mapping, if one does not exist
echo Adding Gateway DNAT Rule…
export DNAT_RULE=$(vca -j nat  | jq --arg public_ip "$PUBLIC_IP" '."nat-rules"[] | select(."Translated IP"==$public_ip) | select(.Type=="DNAT")')
if [ ! "${DNAT_RULE}" ]; then 
   vca nat add --type DNAT --original-ip $PUBLIC_IP --original-port 22 --translated-ip $IP --translated-port 22 --protocol tcp
fi


# Disable the firewall for an initial test
vca firewall disable

# Test the login, login and run a command

ssh-keygen -R ${PUBLIC_IP}
echo Testing Login to VM, run uname command
ssh  ${NEW_VM_USER}@${PUBLIC_IP}  -i ./${NEW_VM_USER}_rsa uname -a


# End of vCloud Air example

