#!/bin/bash
############################################################################
#                                                                          #
# This file is part of the IPFire Firewall.                                #
#                                                                          #
# IPFire is free software; you can redistribute it and/or modify           #
# it under the terms of the GNU General Public License as published by     #
# the Free Software Foundation; either version 3 of the License, or        #
# (at your option) any later version.                                      #
#                                                                          #
# IPFire is distributed in the hope that it will be useful,                #
# but WITHOUT ANY WARRANTY; without even the implied warranty of           #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            #
# GNU General Public License for more details.                             #
#                                                                          #
# You should have received a copy of the GNU General Public License        #
# along with IPFire; if not, write to the Free Software                    #
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA #
#                                                                          #
# Copyright (C) 2025 IPFire-Team <info@ipfire.org>.                        #
#                                                                          #
############################################################################
#
. /opt/pakfire/lib/functions.sh
/usr/local/bin/backupctrl exclude >/dev/null 2>&1

core=195

# Remove old core updates from pakfire cache to save space...
for (( i=1; i<=$core; i++ )); do
	rm -f /var/cache/pakfire/core-upgrade-*-$i.ipfire
done

# Stop services

# Remove files
rm -rfv \
	/usr/lib/perl5/site_perl/5.36.0/Apache/Htpasswd.pm

# Extract files
extract_files

# Remove dropped packages
for package in libmpeg2 xvid; do
        if [ -e "/opt/pakfire/db/installed/meta-${package}" ]; then
                stop_service "${package}"
                for i in $(</opt/pakfire/db/rootfiles/${package}); do
                        rm -rfv "/${i}"
                done
        fi
        rm -f "/opt/pakfire/db/installed/meta-${package}"
        rm -f "/opt/pakfire/db/meta/meta-${package}"
        rm -f "/opt/pakfire/db/rootfiles/${package}"
done

# update linker config
ldconfig

# Create the Wireguard configuration directory
if [ ! -d "/var/ipfire/wireguard" ]; then
	mkdir -pv "/var/ipfire/wireguard"

	# Create some configuration files
	touch /var/ipfire/wireguard/peers
	touch /var/ipfire/wireguard/settings

	# Everything needs to belong to nobody
	chown -Rv nobody:nobody "/var/ipfire/wireguard"
fi

# Update Language cache
/usr/local/bin/update-lang-cache

# Filesytem cleanup
/usr/local/bin/filesystem-cleanup

# Remove any entry for 3CORESEC_SSH, 3CORESEC_SCAN or 3CORESEC_WEB from the ipblocklist modified file
# and the associated ipblocklist files from the /var/lib/ipblocklist directory
sed -i '/3CORESEC_SSH=/d' /var/ipfire/ipblocklist/modified
if [ -e /var/lib/ipblocklist/3CORESEC_SSH.conf ]; then
	rm /var/lib/ipblocklist/3CORESEC_SSH.conf
fi
sed -i '/3CORESEC_SCAN=/d' /var/ipfire/ipblocklist/modified
if [ -e /var/lib/ipblocklist/3CORESEC_SCAN.conf ]; then
	rm /var/lib/ipblocklist/3CORESEC_SCAN.conf
fi
sed -i '/3CORESEC_WEB=/d' /var/ipfire/ipblocklist/modified
if [ -e /var/lib/ipblocklist/3CORESEC_WEB.conf ]; then
	rm /var/lib/ipblocklist/3CORESEC_WEB.conf
fi

# Apply SSH configuration
/usr/local/bin/sshctrl

# Start services
/etc/init.d/firewall restart
/etc/init.d/sshd restart
/etc/init.d/unbound restart

# This update needs a reboot...
#touch /var/run/need_reboot

# Finish
/etc/init.d/fireinfo start
sendprofile

# Update grub config to display new core version
if [ -e /boot/grub/grub.cfg ]; then
	grub-mkconfig -o /boot/grub/grub.cfg
fi

sync

# Don't report the exitcode last command
exit 0
