#!/bin/bash

#############################
# sparse image to raw image #
#############################
./simg2img system.img system.raw.img
./simg2img system_ext.img system_ext.raw.img
./simg2img system_other.img system_other.raw.img
./simg2img product.img product.raw.img
./simg2img vendor.img vendor.raw.img

mkdir -p system
mkdir -p system_ext
mkdir -p system_other
mkdir -p product
mkdir -p vendor

7z x system.raw.img -y -osystem
7z x system_ext.raw.img -y -osystem_ext
7z x system_other.raw.img -y -osystem_other
7z x product.raw.img -y -oproduct
7z x vendor.raw.img -y -ovendor
