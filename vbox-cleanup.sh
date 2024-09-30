#! /bin/bash

for vm in $(VBoxManage list vms | awk '{print $2}' | tr -d '{}'); do     
  VBoxManage controlvm "$vm" poweroff;     
  VBoxManage unregistervm "$vm" --delete; 
done
VBoxManage natnetwork remove --netname "private-net"
rm -rf "/home/chpc/VirtualBox VMs/"*
rm -f *.vdi 

