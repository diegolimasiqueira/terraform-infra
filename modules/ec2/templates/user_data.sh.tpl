#!/bin/bash
echo "easyprofind-${hostname}" > /etc/hostname
hostnamectl set-hostname easyprofind-${hostname}
