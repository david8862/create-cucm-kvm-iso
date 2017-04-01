This is a shell script for creating Cisco CUCM KVM install ISO image, which covers following guide steps 2 to 9
======================================================

## How to create a CUCM .iso image for KVM/Openstack installation:

#### 1. Download bootable .sgn.iso install image from Cisco official webpage, like:
https://software.cisco.com/download/release.html?mdfid=286306100&release=11.5(1)SU2&flowid=79971&atcFlag=N&dwldImageGuid=89807AEE2B4EA3CFB5E790684BBEDD7120F2B182&softwareid=282074295&dwnld=true

#### 2. Put the image onto Linux host, then mount it to a dir:
    $ mkdir /tmp/iso/
    $ mount -o loop UCSInstall_UCOS_10.5.2.14901-1.sgn.iso /tmp/iso/

#### 3. cp the iso path to a writeable path:
    $ mkdir /tmp/CUCM/
    $ rsync -a /tmp/iso/ /tmp/CUCM/

#### 4. check iso content for supported VM platform:
    $ ls /tmp/CUCM/Cisco/hssi/server_implementation/
    KVM  OpenStack  README.TXT  shared  TRANS.TBL  VMWARE
    $ ls /tmp/CUCM/Cisco/hssi/server_implementation/KVM/
    HAL  QEMU  RHEV  shared  TRANS.TBL

#### 5. delete the unneeded VM platform, so that the install process can pick our target platform. For qemu image creat, we need a KVM installation, so delete Openstack and VMWARE, and other hypervisor under KVM, only leave QEMU:

    $ cd /tmp/CUCM/Cisco/hssi/server_implementation/
    $ rm -rf OpenStack VMWARE
    $ cd KVM/
    $ ls
    HAL  QEMU  RHEV  shared  TRANS.TBL
    $ rm -rf HAL RHEV

#### 6. change the install script, add some debug log to print out the Hardware detection result, and add some error handling to bypass the hardware detect failure:
    $ cd /tmp/CUCM/Cisco/hssi/shared/bin/
    $ vim hssi_api.sh

    ## we don't have a model set
    ## look through the paths for valid models
        echo "Detecting Server Hardware - this can take several minutes" >&2
        searchPaths=$(find $server_implementation_path -noleaf -type f -name api_implementation.sh)
        for impl in $searchPaths ; do
            validation_errors=$($impl detect_and_validate)
            isFound=$?
            hssi_log "HSSI_API $impl returned $isFound and errors=$validation_errors "
    +       echo "HSSI_API $impl returned $isFound and errors=$validation_errors " >&2
            case "$isFound" in
                "0")
                echo "$($impl HWModel): passed detection validation" >&2
                append_inDataFile_forKey_value $hssi_api_state_file "hardware_implementation_paths" $impl
                hw_model="$($impl HWModel)"
                ((validated_count++))
                ;;
    +
    +            "2")
    +            echo "$($impl HWModel): passed detection validation" >&2
    +            append_inDataFile_forKey_value $hssi_api_state_file "hardware_implementation_paths" $impl
    +            hw_model="$($impl HWModel)"
    +            ((validated_count++))
    +            ;;

This is my version. The "2" case is from the VM install log output we added. So pls change it based on your result.


#### 7. Change the snmp monitoring function "hasHwSnmpMonitoring" in install script. This is from the demo video on youtube (https://www.youtube.com/watch?v=pPO75mWN1xw):

    $ cd /tmp/CUCM/Cisco/base_scripts
    $ vi ihardware.sh

    function hasHwSnmpMonitoring()
    {
    -    local method="hasHwSnmpMonitoring"
    -    _forwardToSAM $method $@
    +    return 1
    }

#### 8. To remove the HWADDR check in network config script, we need to change the install script as follow:
    $ cd /tmp/CUCM/Cisco/hssi/server_implementation/KVM/QEMU/shared/bin/
    $ mv api_implementation.sh.proposed api_implementation.sh
    $ vi api_implementation.sh

        return $rc
    }

    + function postBootHardwareSetup()
    + {
    +     local rc=$HSSI_TRUE
    +     
    +     (super postBootHardwareSetup $*)
    +     local src=$?
    +     # Abort if there is a critical failure
    +     if [ $src -eq 1 ]; then
    +         return $src
    +     fi
    +     rm -f /etc/udev/rules.d/70-persistent-net.rules 2> /dev/null
    + 
    +     #
    +     # remove hwaddr field from config in case mac address changed.
    +     #
    +     sed -i 's/^HWADDR.*//' /etc/sysconfig/network-scripts/ifcfg-eth* 2> /dev/null
    +     sed -i 's/^NM_CON.*/NM_CONTROLLED="no"/' /etc/sysconfig/network-scripts/ifcfg-eth* 2> /dev/null
    +     sed -i 's/^ONBOOT.*/ONBOOT="yes"/' /etc/sysconfig/network-scripts/ifcfg-eth* 2> /dev/null
    +     return $rc
    + }
    
    _runtime $@

    
    $ cd /tmp/CUCM/Cisco/hssi/server_implementation/KVM/shared/bin
    $ vi shared_implementation.sh
    
        return $rc
    }

    + function postBootHardwareSetup()
    + {
    +     local rc=$HSSI_TRUE
    +     
    +     (super postBootHardwareSetup $*)
    +     local src=$?
    +     # Abort if there is a critical failure
    +     if [ $src -eq 1 ]; then
    +         return $src
    +     fi
    +     rm -f /etc/udev/rules.d/70-persistent-net.rules 2> /dev/null
    + 
    +     #
    +     # remove hwaddr field from config in case mac address changed.
    +     #
    +     sed -i 's/^HWADDR.*//' /etc/sysconfig/network-scripts/ifcfg-eth* 2> /dev/null
    +     sed -i 's/^NM_CON.*/NM_CONTROLLED="no"/' /etc/sysconfig/network-scripts/ifcfg-eth* 2> /dev/null
    +     sed -i 's/^ONBOOT.*/ONBOOT="yes"/' /etc/sysconfig/network-scripts/ifcfg-eth* 2> /dev/null
    +     return $rc
    + }

    _runtime $@



#### 9. After finishing all the changes, use the changed version to create a new iso image:

    $ cd /tmp/CUCM/
    $ mkisofs -o /home/skywalker/CUCM_KVM_10.5.2.sgn.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R .


#### 10. Use the created iso image to launch a KVM VM and install a CUCM via virt-manager. Then use qemu-img tool to convert a compressed qcow2 image:

    $ cd /var/lib/libvirt/images/
    $ qemu-img convert -f qcow2 -O qcow2 test4.img cucm_10.5.2.qcow2


#### 11. Upload the qcow2 image file to controller node and add to open stack:
    $ openstack image create "cucm 10.5.2" --file cucm_10.5.2.qcow2 --disk-format qcow2 --container-format bare --public
