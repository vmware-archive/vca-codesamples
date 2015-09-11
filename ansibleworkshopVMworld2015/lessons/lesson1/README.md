# ad-hoc examples

### Topics Covered

* ansible installation methods
* ad-hoc ansible
* command-line options: ```-i -u -m -a```
* using ansible.cfg

### General flow

First, we will install Ansible.
Then ensure connection to the vCloud Air Subscription using Ansible.

### Commands
Install pip

	sudo easy_install pip

Install ansible with pip.

	sudo pip install ansible

Run the following commands and experiment:

	ansible test -m ping --ask-pass

	ansible test -m setup --ask-pass

	ansible test -m file -a "path=/opt/vdc_name state=directory mode='u+rw,g-wx,o-rwx'"

### Reverse Engineer

Using the above commands as examples write an Ansible task to create a file of
your assigned VDC in the above directory.
