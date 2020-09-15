# SETT's Cloud Infrastructure

# Quick Setup:
```
vagrant up
ansible-playbook -i vagrant.inventory ansible/site.yml -b
```
Those two commands will start two virtualbox vm's and install the ipad
webserver & database server roles to each. Easy!

# About these playbooks:

These playbooks will deploy all of the servers required for SETT's cloud
infrastructure. That currently means:

* Frontend servers, including:
  * Load Balancers (HAProxy)
  * Apache
  * Python WSGI Server
* Backend
  * PostgreSQL (With Master/Slave Replication)
  * PGBouncer
* LDM Servers, processing:
  * METAR
  * MADIS
  * UK & US Radar imagery.
* ForecastDB
* Monitoring (with Nagios)
* DQM

This is all done using '[ansible](ansible.com)'. It's free software that
communicates with the target servers via ssh. No preinstallation of daemons
required.

**There's really only one question, where do you want to deploy it?**

The same playbooks (and even the same configuration) is used to deploy to
production, staging, testing. Whether that be metal, in the cloud or running on
virtual machines on your laptop. This repository includes a sample Vagrant
configuration file which will get you set up immediately by creating some
virtual machine.

## Requirements:
* [ansible](ansible.com)
  * Version 2+ is required.
* Either:
  * [Virtualbox](virtualbox.org) & [Vagrant](vagrantup.com)
    (If you want to test locally.) or...
  * Remote hosts accepting your private ssh key. (Whether metal/cloud, root/not,
    it doesn't matter.)

If you're on windows, check out the README-Windows.md before returning to follow
the rest of this document. You can't just pip install ansible!

## Vagrant

If you are just testing and aren't ready to deploy to real machines yet, use
Vagrant to bring up virtual machines quickly. (Or build your own, whatever)

1. Decide what machines you want, comment them in and out of the following files.
   The default is for a single www & db machine for the ipad infrastructure.
   Don't forget to comment out the group assignments.
   * Vagrantfile
   * inventories/vagrant
2. Bring up the virtual machines
   ```
   vagrant up
   ```

You'll want to use inventories/vagrant later on with ansible:

## Ansible

Whatever we're planning, these steps need to be followed first:

1. ** If you're just using vagrant, go to step 3! **
   Otherwise, you need to create an inventories file (use inventories/example)
   and a variables file to match your configuration.
   ```
   cp inventories/example inventories/inventoryname
   vi inventories/inventoryname
   cp ansible/group_vars/example ansible/group_vars/inventoryname
   vi ansible/group_vars/inventoryname
   ```
2. Run ssh-keygen and overwrite the keys at the following locations with keys
   that have no password.
   * ansible/roles/database/files/postgres_rsa
   * ansible/roles/ldm/files/ldm_rsa
3. Finally, deploy!
   ```
   ansible-playbook -i vagrant.inventory ansible/site.yml -b
   ```
   If your setup requires a sudo password, pop on `--ask-become-pass` also.

## Production Deployments

Various production environments are already set up in this repository.

For example, the dqm-pre environment can be deployed using:
```
ansible-playbook ansible/site.yml -i inventories/dqm-pre --ask-vault-pass -b
```
This works because all hosts within `inventories/dqm-pre` are included in a
group named `dqm-pre`. There is then a directory of group variables for them
in `ansible/group-vars/dqm-pre`.

Sensitive details such as passwords shouldn't be stored in a vcs in plaintext.
We use [ansible vault](http://docs.ansible.com/ansible/playbooks_vault.html)
to encrypt these passwords. The `--ask-vault-pass` then prompts for the
password to unlock them.

If you'd like to create a new permenant deployment, you'll need to create a
new `inventories` and `ansible/group_vars/` set of files using the examples.
# cloud-infra
# cloud-infra
# cloud-infra
