# Sync twrp-10.0 minimal manifest and patch it for building OrangeFox for dynamic partition devices

## To fetch the manifest for the first time, follow these steps: ##
------------------------------------

### 1. Fetch these sync tools ###
	mkdir ~/OrangeFox_10
	cd ~/OrangeFox_10
	git clone git@gitlab.com:OrangeFox/sync.git

### 2. Do the syncing (this can take up to 1 hour, and can use up to 40GB of disk space) ##
	cd ~/OrangeFox_10/sync
	./get_fox_10.sh ~/OrangeFox_10/fox_10.0
(if the sync process gets stuck, you might need to terminate it with Ctrl-C and then run the script again)

## To update the manifest, recovery sources, and vendor trees, follow these steps: ##
----------------------------------
	cd ~/OrangeFox_10/sync
	./update_fox_10.sh ~/OrangeFox_10/fox_10.0

## To update only the recovery sources, follow these steps: ##
----------------------------------
	cd ~/OrangeFox_10/fox_10.0/bootable/recovery
	git pull

## To update only the vendor tree, follow these steps: ##
----------------------------------
	cd ~/OrangeFox_10/fox_10.0/vendor/recovery
	git pull

### 3. To build, using a trivial sample build script, follow these steps: ###
----------------------------------
	cd ~/OrangeFox_10/sync
	./build_fox.sh <device_codename>
(make sure that you have cloned your device tree to the correct place before doing this!)

