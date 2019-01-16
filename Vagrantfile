# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant::DEFAULT_SERVER_URL.replace('https://vagrantcloud.com')

# Load ~/.VagrantFile if exist, permit local config provider
vagrantfile = File.join("#{Dir.home}", '.VagrantFile')
load File.expand_path(vagrantfile) if File.exists?(vagrantfile)

Vagrant.configure('2') do |config|
  config.vm.synced_folder "./", "/vagrant", type: "rsync", rsync__exclude: [ '.vagrant', '.git' ]
  config.ssh.shell="/bin/sh"

  $deps = <<SCRIPT
mkdir -p /etc/shellpki
id shellpki 2>&1 >/dev/null || useradd shellpki --system -M --home-dir /etc/shellpki --shell /usr/sbin/nologin
ln -sf /vagrant/openssl.cnf /etc/shellpki/
ln -sf /vagrant/shellpki.sh /usr/local/sbin/shellpki
SCRIPT

  config.vm.define :shellpki do |node|
    node.vm.hostname = "shellpki"
    node.vm.box = "debian/stretch64"

    node.vm.provision "deps", type: "shell", :inline => $deps
  end

end
