# -*- mode: ruby -*-
# vi: set ft=ruby :

# Load ~/.VagrantFile if exist, permit local config provider
vagrantfile = File.join("#{Dir.home}", '.VagrantFile')
load File.expand_path(vagrantfile) if File.exists?(vagrantfile)

Vagrant.configure('2') do |config|
  config.vm.synced_folder "./", "/vagrant", type: "rsync", rsync__exclude: [ '.vagrant', '.git' ]
  config.ssh.shell="/bin/sh"

  $deps = <<SCRIPT
mkdir -p /etc/shellpki
if [ "$(uname)" = "Linux" ]; then
    id shellpki 2>&1 >/dev/null || useradd shellpki --system -M --home-dir /etc/shellpki --shell /usr/sbin/nologin
fi
if [ "$(uname)" = "OpenBSD" ]; then
    id _shellpki 2>&1 >/dev/null || useradd -r 1..1000 -d /etc/shellpki -s /sbin/nologin _shellpki
fi
ln -sf /vagrant/openssl.cnf /etc/shellpki/
ln -sf /vagrant/shellpki /usr/local/sbin/shellpki
SCRIPT

  nodes = [
    { :name => "debian", :box => "debian/stretch64" },
    { :name => "openbsd", :box => "generic/openbsd6" }
  ]

  nodes.each do |i|
    config.vm.define "#{i[:name]}" do |node|
      node.vm.hostname = "shellpki-#{i[:name]}"
      node.vm.box = "#{i[:box]}"

      config.vm.provision "deps", type: "shell", :inline => $deps
    end
  end


end
