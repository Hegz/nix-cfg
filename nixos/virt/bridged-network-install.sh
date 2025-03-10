#!/usr/bin/env bash
virsh --connect qemu:///system net-define bridged-network.xml
virsh --connect qemu:///system net-start bridged-network
virsh --connect qemu:///system net-autostart bridged-network
