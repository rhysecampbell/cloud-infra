# Orchestration in Rackspace

Included is a copy of `rack`, the rackspace go api.

The first thing you'll want to do is run:
```
bin/rack configure
```

With that, you'll then be able to create a new stack using one of the templates in this folder.

e.g.
```
rack orchestration stack create --name jpc-dqm --template-file rackspace/dqm.yml --parameters key_name=jpc
```

You'll then get some output like the following:
```
ID      8aca2ed9-87dd-4f75-aeac-7f4f270f1d81
Links0:Rel  self
Links0:Href https://ord.orchestration.api.rackspacecloud.com/v1/853326/stacks/jpc/8aca2ed9-87dd-4f75-aeac-7f4f220f1d81
```
If you want to deploy it to a different network or dns address, add extra parameters as below:
```
rack orchestration stack create --name jpc-dqm --template-file rackspace/dqm.yml --parameters key_name=jpc,domain=vaicld-test.com,network=DQM-test
```

You can then use things like
```
rack orchestration stack list-events -name jpc-dqm
```
to see what's going on with it, or use the web interface.

Included in these templates are output variables that will produce your ansible inventory file & dns zone files. Just copy them where you need them from the link returned.

## Destruction.

The command line tool is hopefully quite easy to find your way around, the self-contained documentation is great and it is more fully documented here: https://developer.rackspace.com/docs/rack-cli/services/orchestration/#orchestration

As an example of updating your stack (it may destroy servers):
```
rack orchestration stack update --name jpc-dqm --template-file rackspace/dqm.yml --parameters key_name=jpc
```
and destruction:
```
rack orchestration stack delete --name jpc-dqm
```

## Ansible deployment.
So you've got your stack, lets deploy to it...

### Deploy 0
First, make sure you've copied the inventory file from the web ui (or ```rack orchestration stack get -name jpc-dqm```) into a file. It's the output parameter marked 'Deploy 0'.

### Deploy 1
Next you need to make sure you can ssh to each individual machine. There's a handy command generated in the section marked 'Deploy 1'.

### Deploy 2
Then run ansible to set up ssh keys etc. The correct command is listed in the stack output as, you guessed it, 'Deploy 2', but here's an example:
```
ansible-playbook ansible/site.yml -i inventories/dqm-jpc -u root -t ssh -l \!panopticon.vaicld-test.com
```

### Deploy 3
Then you can run ansible "for real". Again, use the output of the stack template ('Deploy 3'), but here's an example:
```
ansible-playbook ansible/site.yml -i inventories/dqm-jpc -b
```
