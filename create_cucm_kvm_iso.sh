#! /bin/bash
# Filename: create_cucm_kvm_iso.sh
#
# Copyright (C) 2017  Xiaobin Zhang (david8862@gmail.com)
#
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 2.1 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

#
# main()
#
if [ $# -ne 2 ] ; then
	echo Usage: "`basename $0` SOURCE_ISO DEST_ISO"
	echo "SOURCE_ISO  origin iso image get from Cisco webpage"
	echo "DEST_ISO    output iso image supporting KVM installation"
	exit 1
fi

SOURCE_ISO=$1
DEST_ISO=$2
CURR_PATH=$(pwd)


if [ $(id -un) != "root" ]; then
    echo "Please use root account."
    exit 1
fi

if [ ! -f "$SOURCE_ISO" ]; then
    echo "origin iso un-exists. Please check again."
    exit 1
fi

umount /tmp/iso
umount /tmp/CUCM
rm -rf /tmp/iso
rm -rf /tmp/CUCM
mkdir /tmp/iso
mkdir /tmp/CUCM

mount -o loop $SOURCE_ISO /tmp/iso/
echo "Now syncing ISO to new path, please wait..."
rsync -a /tmp/iso/ /tmp/CUCM/
echo "Syncing finished."

#Remove not used server implementation
pushd /tmp/CUCM/Cisco/hssi/server_implementation/
shopt -s extglob
rm -rf !(KVM|README.TXT|shared|TRANS.TBL)
pushd KVM/
rm -rf !(QEMU|shared|TRANS.TBL)
shopt -u extglob
popd
popd


#Add server hardware detecting error check
sed -i '/HSSI_API $impl returned $isFound and errors/i\            echo "HSSI_API $impl returned $isFound and errors=$validation_errors " >&2' /tmp/CUCM/Cisco/hssi/shared/bin/hssi_api.sh

sed -i '/case "$isFound" in/G' /tmp/CUCM/Cisco/hssi/shared/bin/hssi_api.sh
sed -i '/case "$isFound" in/a\                ;;' /tmp/CUCM/Cisco/hssi/shared/bin/hssi_api.sh
sed -i '/case "$isFound" in/a\                ((validated_count++))' /tmp/CUCM/Cisco/hssi/shared/bin/hssi_api.sh
sed -i '/case "$isFound" in/a\                hw_model="$($impl HWModel)"' /tmp/CUCM/Cisco/hssi/shared/bin/hssi_api.sh
sed -i '/case "$isFound" in/a\                append_inDataFile_forKey_value $hssi_api_state_file "hardware_implementation_paths" $impl' /tmp/CUCM/Cisco/hssi/shared/bin/hssi_api.sh
sed -i '/case "$isFound" in/a\                echo "$($impl HWModel): passed detection validation" >&2' /tmp/CUCM/Cisco/hssi/shared/bin/hssi_api.sh
sed -i '/case "$isFound" in/a\                "2")' /tmp/CUCM/Cisco/hssi/shared/bin/hssi_api.sh

#Snmp
sed -i '/local method="hasHwSnmpMonitoring"/{n;d}' /tmp/CUCM/Cisco/base_scripts/ihardware.sh
sed -i 's/local method="hasHwSnmpMonitoring"/return 1/g' /tmp/CUCM/Cisco/base_scripts/ihardware.sh

#Remove eth HWADDR check
mv /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh.proposed /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh


sed -i '/_runtime $@/i\function postBootHardwareSetup()' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i '/_runtime $@/i\{' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i '/_runtime $@/i\    local rc=$HSSI_TRUE' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i '/_runtime $@/i\\' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i '/_runtime $@/i\    (super postBootHardwareSetup $*)' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i '/_runtime $@/i\    local src=$?' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i '/_runtime $@/i\    # Abort if there is a critical failure' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i '/_runtime $@/i\    if [ $src -eq 1 ]; then' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i '/_runtime $@/i\        return $src' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i '/_runtime $@/i\    fi' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i '/_runtime $@/i\    rm -f /etc/udev/rules.d/70-persistent-net.rules 2> /dev/null' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i '/_runtime $@/i\\' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i '/_runtime $@/i\    #' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i '/_runtime $@/i\    # remove hwaddr field from config in case mac address changed.' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i '/_runtime $@/i\    #' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i "/_runtime \$\@/i\    sed -i 's/^HWADDR.*//' /etc/sysconfig/network-scripts/ifcfg-eth* 2> /dev/null" /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i "/_runtime \$\@/i\    sed -i 's/^NM_CON.*/NM_CONTROLLED="no"/' /etc/sysconfig/network-scripts/ifcfg-eth* 2> /dev/null" /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i "/_runtime \$\@/i\    sed -i 's/^ONBOOT.*/ONBOOT="yes"/' /etc/sysconfig/network-scripts/ifcfg-eth* 2> /dev/null" /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i "/_runtime \$\@/i\    return \$rc" /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i '/_runtime $@/i\}' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh
sed -i '/_runtime $@/i\\' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/api_implementation.sh





sed -i '/_runtime $@/i\function postBootHardwareSetup()' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i '/_runtime $@/i\{' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i '/_runtime $@/i\    local rc=$HSSI_TRUE' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i '/_runtime $@/i\\' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i '/_runtime $@/i\    (super postBootHardwareSetup $*)' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i '/_runtime $@/i\    local src=$?' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i '/_runtime $@/i\    # Abort if there is a critical failure' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i '/_runtime $@/i\    if [ $src -eq 1 ]; then' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i '/_runtime $@/i\        return $src' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i '/_runtime $@/i\    fi' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i '/_runtime $@/i\    rm -f /etc/udev/rules.d/70-persistent-net.rules 2> /dev/null' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i '/_runtime $@/i\\' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i '/_runtime $@/i\    #' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i '/_runtime $@/i\    # remove hwaddr field from config in case mac address changed.' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i '/_runtime $@/i\    #' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i "/_runtime \$\@/i\    sed -i 's/^HWADDR.*//' /etc/sysconfig/network-scripts/ifcfg-eth* 2> /dev/null" /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i "/_runtime \$\@/i\    sed -i 's/^NM_CON.*/NM_CONTROLLED="no"/' /etc/sysconfig/network-scripts/ifcfg-eth* 2> /dev/null" /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i "/_runtime \$\@/i\    sed -i 's/^ONBOOT.*/ONBOOT="yes"/' /etc/sysconfig/network-scripts/ifcfg-eth* 2> /dev/null" /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i "/_runtime \$\@/i\    return \$rc" /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i '/_runtime $@/i\}' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh
sed -i '/_runtime $@/i\\' /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin/shared_implementation.sh




pushd /tmp/CUCM/
mkisofs -o $CURR_PATH/$DEST_ISO -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R .
popd

umount /tmp/iso
umount /tmp/CUCM
rm -rf /tmp/iso
rm -rf /tmp/CUCM
echo "KVM ISO is created at $CURR_PATH/$DEST_ISO"



