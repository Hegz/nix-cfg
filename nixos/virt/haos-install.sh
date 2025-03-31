#!/usr/bin/env bash

set -e

virt-install \
	--connect qemu:///system \
	--name haos \
	--boot uefi \
	--metadata description="Home Assistant OS" \
	--os-variant generic \
	--memory 4096 \
	--cpu host-passthrough \
	--vcpus 2 \
	--import --disk /home/virt/haos_ova-14.2.qcow2,bus=scsi \
	--controller type=scsi,model=virtio-scsi \
	--network network=bridged-network \
	--noautoconsole
