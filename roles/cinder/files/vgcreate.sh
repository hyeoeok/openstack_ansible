#!/bin/bash

lvm_device_name="sdb"

IFS=',' read -ra devices <<< "$lvm_device_name"

vgcreate cinder-volumes "${devices[@]/#/\/dev\/}"
