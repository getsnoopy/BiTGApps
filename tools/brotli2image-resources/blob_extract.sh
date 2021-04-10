#!/bin/bash

###################
# brotli to image #
###################
brotli --decompress system.new.dat.br
brotli --decompress vendor.new.dat.br

curl -sLo sdat2img.py https://raw.githubusercontent.com/xpirt/sdat2img/master/sdat2img.py
python3 sdat2img.py system.transfer.list system.new.dat system.img
python3 sdat2img.py vendor.transfer.list vendor.new.dat vendor.img

mkdir -p system
mkdir -p vendor

7z x system.img -y -osystem
7z x vendor.img -y -ovendor
