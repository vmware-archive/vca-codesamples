#!/bin/bash

# Login to a Subscription service instance

vca login user@example.com   --password ‘mypassword’   --host vchs.vmware.com   --version 5.6 --org M933009684-9999  --instance M933009684-9999 

# OR

# Login to an onDemand service instance

vca login user@example.com    --password  ‘mypassword’   --instance 97453e02-e83c-4cae-bbe9-3f7ff6dd8401 --vdc VDC1 


# List all VMs in the VDC

vca vm list

# end session

vca logout