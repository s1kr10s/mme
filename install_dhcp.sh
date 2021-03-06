#!/bin/sh -e
# This script will install a DHCP server, configure it, and run it on the
# first en* network interface
eth0=`ifconfig | grep ^en | head -n 1 | sed 's/:.*//g'`
if [ -z "$eth0" ]; then
  eth0="wlan1"  # serve up DHCP addresses on wlan1
fi
ip="192.168.101.1"
network="192.168.101.0"
netmask="255.255.255.0"
search_domain="example.lan"
nameserver="4.2.2.2"
dhcp_start="192.168.101.10"
dhcp_end="192.168.101.100"

distro_id=`grep ^ID= /etc/os-release | sed 's/.*=//g'`
if [ "$distro_id" != "fedora" -a "$distro_id" != "debian" ]; then
  distro_id=`grep ^ID_LIKE= /etc/os-release | sed 's/.*=//g'`
  if [ "$distro_id" != "fedora" -a "$distro_id" != "debian" ]; then
    echo "Unsupported distro: $distro_id"
    exit 1
  fi
fi

# Set the host IP
sudo ifconfig $eth0 $ip

if [ "$distro_id" = "fedora" ]; then
  sudo dnf install -y dhcp
  # Configure the server
  sudo cp /usr/lib/systemd/system/dhcpd.service /etc/systemd/system/
  service_name="dhcpd"
else
  if [ "$distro_id" = "debian" ]; then
    sudo apt-get install -y isc-dhcp-server # Ubuntu
  fi
  service_name="isc-dhcp-server"
fi

echo "subnet $network netmask $netmask {"             | sudo tee /etc/dhcp/dhcpd.conf
echo "    option routers $ip;"                        | sudo tee -a /etc/dhcp/dhcpd.conf
echo "    option subnet-mask $netmask;"               | sudo tee -a /etc/dhcp/dhcpd.conf
echo "    option domain-search   \"$search_domain\";" | sudo tee -a /etc/dhcp/dhcpd.conf
echo "    option domain-name-servers $nameserver;"    | sudo tee -a /etc/dhcp/dhcpd.conf
echo "    range $dhcp_start $dhcp_end;"               | sudo tee -a /etc/dhcp/dhcpd.conf
echo "}"                                              | sudo tee -a /etc/dhcp/dhcpd.conf

echo "Config file written"
sudo systemctl start $service_name
sudo systemctl status $service_name

echo ""
echo "DHCP server should now be running.  To make this persistent, run:"
echo "sudo systemctl enable $service_name"
echo ""
