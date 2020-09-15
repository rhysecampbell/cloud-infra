Ansible depends on ssh, various standard linux file system layouts, default
linux python, non-windows python libraries etc. so we can't use a windows python
install.

Instead, we're going to use Cygwin to replicate a nix environment on Windows.
This doesn't support a few features (such as ssh ControlMaster) but we'll make
it work!

1. Download & install the following:
   * [Virtualbox](https://www.virtualbox.org/wiki/Downloads)
   * [Vagrant](https://www.vagrantup.com/downloads.html)
   * [Cygwin](https://www.cygwin.com/)
     * Include the following packages:
       * curl
       * python (2.7.x)
       * python-crypto
       * python-openssl
       * python-devel
       * python-setuptools
       * vim
       * openssh
       * openssl
       * openssl-devel
       * git
2. In a cygwin terminal:
   ```
   easy_install-2.7 pip
   pip install ansible
   mkdir /etc/ansible/
   curl http://haproxy.dsbir.vaisala.com/static/windows-ansible.cfg > /etc/ansible/ansible.cfg
   ```

You should now be ready to rejoin README.md using the cygwin terminal.

---
These instructions were adapted from https://servercheck.in/blog/running-ansible-within-windows
