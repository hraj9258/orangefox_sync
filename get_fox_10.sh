#!/bin/bash
# ***************************************************************************************
# - Script to set up things for building OrangeFox with the Android-10.0 build system
# - Syncs the twrp-10.0 minimal manifest, and patches it for building OrangeFox
# - Pulls in the OrangeFox recovery sources and vendor tree
# - Author:  DarthJabba9
# - Version: 003
# - Date:    07 January 2021
# ***************************************************************************************

# Our starting point (Fox base dir)
BASE_DIR="$PWD";

# default directory for the new manifest
MANIFEST_DIR="$BASE_DIR/fox_10.0/";

# where to log the location of the manifest directory upon successful sync and patch
SYNC_LOG="$BASE_DIR/manifest.sav";

# help
if [ "$1" = "-h" -o "$1" = "--help"  -o "$1" = "help" ]; then
  echo "Script to set up things for building OrangeFox with the Android-10.0 build system"
  echo "Usage   = $0 [new_manifest_directory]"
  echo "The default new manifest directory is \"$MANIFEST_DIR\""
  exit 0
fi

# You can supply a path for the new manifest to override the default
[ -n "$1" ] && MANIFEST_DIR="$1";

# use SSH for the "git clone" commands; do NOT change this unless it causes problems
USE_SSH="0"; 

# the "diff" file that will be used to patch the original manifest
PATCH_FILE="$BASE_DIR/patch-manifest.diff";

# the branches we will be dealing with
FOX_10_BRANCH="fox_10.0";
TWRP_10_BRANCH="twrp-10.0";
 
# the directory in which the patch of the manifest will be executed
MANIFEST_BUILD_DIR="$MANIFEST_DIR/build";

# the device whose tree we can clone for compiling a test build
test_build_device="mido";

# print message and quit
abort() {
  echo "$@"
  exit
}

# init the script, ensure we have the patch file, and create the manifest directory
init_script() {
  echo "-- Starting the script ..."
  [ ! -f "$PATCH_FILE" ] && abort "-- I cannot find the patch file: $PATCH_FILE - quitting!"

  echo "-- The new build system will be located in \"$MANIFEST_DIR\""
  mkdir -p $MANIFEST_DIR
  [ "$?" != "0" -a ! -d $MANIFEST_DIR ] && {
    abort "-- Invalid directory: \"$MANIFEST_DIR\". Quitting."
  }
}

# repo init and repo sync
get_twrp_minimal_manifest() {
  local MIN_MANIFEST="git://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git"
  cd $MANIFEST_DIR
  echo "-- Initialising the $TWRP_10_BRANCH minimal manifest repo ..."
  repo init --depth=1 -u $MIN_MANIFEST -b $TWRP_10_BRANCH
  [ "$?" != "0" ] && {
   abort "-- Failed to initialise the minimal manifest repo. Quitting."
  }
  echo "-- Done."

  echo "-- Syncing the $TWRP_10_BRANCH minimal manifest repo ..."
  repo sync
  [ "$?" != "0" ] && {
   abort "-- Failed to Sync the minimal manifest repo. Quitting."
  }
  echo "-- Done."
}

# patch the build system for OrangeFox
patch_minimal_manifest() {
   echo "-- Patching the $TWRP_10_BRANCH minimal manifest for building OrangeFox for dynamic partition devices ..."
   cd $MANIFEST_BUILD_DIR
   patch -p1 < $PATCH_FILE
   [ "$?" = "0" ] && echo "-- The $TWRP_10_BRANCH minimal manifest has been patched successfully" || abort "-- Failed to patch the $TWRP_10_BRANCH minimal manifest! Quitting."

   # save location of manifest dir
   echo "#" &> $SYNC_LOG
   echo "MANIFEST_DIR=$MANIFEST_DIR" >> $SYNC_LOG
   echo "#" >> $SYNC_LOG
}

# get the OrangeFox recovery sources
clone_fox_recovery() {
local URL=""
   if [ "$USE_SSH" = "0" ]; then
      URL="https://gitlab.com/OrangeFox/bootable/Recovery.git"
   else
      URL="git@gitlab.com:OrangeFox/bootable/Recovery.git"
   fi

   mkdir -p $MANIFEST_DIR/bootable
   [ ! -d $MANIFEST_DIR/bootable ] && {
      echo "-- Invalid directory: $MANIFEST_DIR/bootable"
      return
   }

   cd $MANIFEST_DIR/bootable/
   [ -d recovery/ ] && {
      echo  "-- Moving the TWRP recovery sources to /tmp"
      rm -rf /tmp/recovery
      mv recovery /tmp
   }

   echo "-- Pulling the OrangeFox recovery sources ..."
   git clone $URL -b $FOX_10_BRANCH recovery
   [ "$?" = "0" ] && echo "-- The OrangeFox sources have been cloned successfully" || echo "-- Failed to clone the OrangeFox sources!"
   
   # cleanup /tmp/recovery/
   echo  "-- Cleaning up the TWRP recovery sources from /tmp"
   rm -rf /tmp/recovery
   
   # create the directory for Xiaomi device trees
   mkdir -p $MANIFEST_DIR/device/xiaomi
}

# get the OrangeFox vendor
clone_fox_vendor() {
local URL
   if [ "$USE_SSH" = "0" ]; then
      URL="https://gitlab.com/OrangeFox/vendor/recovery.git"
   else
      URL="git@gitlab.com:OrangeFox/vendor/recovery.git"
   fi
   
   echo "-- Preparing for cloning the OrangeFox vendor tree ..."
   rm -rf $MANIFEST_DIR/vendor/recovery
   mkdir -p $MANIFEST_DIR/vendor
   [ ! -d $MANIFEST_DIR/vendor ] && {
      echo "-- Invalid directory: $MANIFEST_DIR/vendor"
      return
   }
   
   cd $MANIFEST_DIR/vendor
   echo "-- Pulling the OrangeFox vendor tree ..."
   git clone $URL -b $FOX_10_BRANCH recovery
   [ "$?" = "0" ] && echo "-- The OrangeFox vendor tree has been cloned successfully" || echo "-- Failed to clone the OrangeFox vendor tree!"
}

# get device trees
get_device_tree() {
local DIR=$MANIFEST_DIR/device/xiaomi
   mkdir -p $DIR
   cd $DIR
   [ "$?" != "0" ] && {
      abort "-- get_device_tree() - Invalid directory: $DIR"
   }

   # test device
   local URL=git@gitlab.com:OrangeFox/device/"$test_build_device".git
   [ "$USE_SSH" = "0" ] && URL=https://gitlab.com/OrangeFox/device/"$test_build_device".git
   echo "-- Pulling the $test_build_device device tree ..."
   git clone $URL -b $FOX_10_BRANCH"_test" "$test_build_device"

   # done
   if [ -d "$test_build_device" -a -d "$test_build_device/recovery" ]; then
      echo "-- Finished fetching the OrangeFox $test_build_device device tree."
   else
      abort "-- get_device_tree() - could not fetch the OrangeFox $test_build_device device tree."
   fi
}

# test build
test_build() {
   # clone the device tree
   get_device_tree

   # proceed with the test build   
   export FOX_VERSION="R11.0_0_fox_10"
   export FOX_BUILD_TYPE="Alpha"
   export ALLOW_MISSING_DEPENDENCIES=true
   export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1
   export LC_ALL="C"
   export FOX_BUILD_DEVICE="$test_build_device"

   echo "-- Compiling a test build for device \"$test_build_device\". This will take a *VERY* long time ..."
   echo "-- Start compiling: "
   export OUT_DIR=$BASE_DIR/BUILDS/"$test_build_device"
   cd $BASE_DIR/
   mkdir -p $OUT_DIR
   cd $MANIFEST_DIR/

   . build/envsetup.sh
   lunch omni_"$test_build_device"-eng
   mka recoveryimage

   # any results?
   ls -all $(find "$OUT_DIR" -name "OrangeFox-*")
}

# do all the work!
WorkNow() {
    local START=$(date);
    init_script;
    get_twrp_minimal_manifest;
    patch_minimal_manifest;
    clone_fox_recovery;
    clone_fox_vendor;
    # test_build; # comment this out - don't do a test build
    local STOP=$(date);
    echo "- Stop time =$STOP";
    echo "- Start time=$START";
    echo "- Now, clone your device trees to the correct locations!";
    exit 0;
}

# --- main() ---
WorkNow;
# --- end main() ---
