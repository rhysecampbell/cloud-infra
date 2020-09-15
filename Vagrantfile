# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

boxes = [
    ## Cloud:
    { :name => :"www1.vagrant", :ip => '172.23.33.11', :ssh_port => 2211 },
    #{ :name => :"www2.vagrant", :ip => '172.23.33.12', :ssh_port => 2212 },
    { :name => :"db1.vagrant", :ip => '172.23.33.21', :ssh_port => 2221 },
    #{ :name => :"db2.vagrant", :ip => '172.23.33.22', :ssh_port => 2222 },
    #{ :name => :"ldm.vagrant", :ip => '172.23.33.31', :ssh_port => 2231 },
    #{ :name => :"fcast.vagrant", :ip => '172.23.33.32', :ssh_port => 2232 },
    ##
    ## DQM:
    #{ :name => :"db1.dqm.vagrant", :ip => '172.23.33.51', :ssh_port => 2251 },
    #{ :name => :"idb1.dqm.vagrant", :ip => '172.23.33.52', :ssh_port => 2252 },
    #{ :name => :"proc1.dqm.vagrant", :ip => '172.23.33.53', :ssh_port => 2253 },
    #{ :name => :"www1.dqm.vagrant", :ip => '172.23.33.54', :ssh_port => 2254 },
    ##
    ## Monitoring:
    #{ :name => :"nagios.vagrant", :ip => '172.23.33.71', :ssh_port => 2271 },
]

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box = "puppetlabs/centos-6.6-64-nocm"
  
  boxes.each do |opts|
      config.vm.define opts[:name] do |config|
          config.vm.network :forwarded_port,
              host: opts[:ssh_port],
              guest: 22,
              id: 'ssh'
          config.vm.hostname = opts[:name]
          config.vm.network :private_network, ip: opts[:ip]

          config.vm.provider :virtualbox do |vb|
              vb.customize ["modifyvm", :id, "--name", opts[:name]]
          end
      end
  end

end
