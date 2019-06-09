#!/bin/bash

# Path the the compiler executable
SP_COMP_EXE=/home/smuser/sourcemod/addons/sourcemod/scripting/spcomp

# Working directory for custom plugins
# Check if the build dor was set, if not, use the default one, provided by GitLab Runner
if [ ! -n "${BUILD_DIR+1}" ]; then
	if [ ! -n "${CI_PROJECT_DIR+1}" ]; then
		echo "ERROR: Neither the BUILD_DIR nor the CI_PROJECT_DIR is set. Please provide a working directory"
		exit 1;
	fi
	BUILD_DIR=$CI_PROJECT_DIR
	echo "BUILD_DIR was not set, using default: $BUILD_DIR"
fi

# Dir for compiled plugins
COMPILE_DIR=$BUILD_DIR/compiled

# Replace versions with git tag describe / hash if AUTO_VERSION_REPLACE is set
if [ -n "${AUTO_VERSION_REPLACE+1}" ]; then
	echo ""
	echo "AUTO_VERSION_REPLACE is set, resolving ..."
	echo -n "Resolved git version for version replacement: "
	REPLACE_VERSION=`git describe`
	if [ $? -eq 0 ]; then
		echo "Using git describe output: $REPLACE_VERSION"
	else
		# We were unable to get a version by using "git describe", use hash instead
		echo -n "Unable to get version replacement by using git describe, using hash instead: "
		GIT_HASH=`git log --pretty=format:'%h' -n 1`
		echo "$GIT_HASH"
		REPLACE_VERSION="dev-$GIT_HASH"
	fi
	echo "REPLACE_VERSION=$REPLACE_VERSION"
	echo ""
fi

additional_params=$1
echo "Using additional params: $additional_params"

function compile_failed() {
        echo "Seem like a script does not compile, check error out from spcomp above for more details"
        exit 1;
}

# Change to the root of the sourcemod scripting directory so sourcemod can find all its include dependencies

echo "Compiled smx files going to: $COMPILE_DIR"

# Check if the build dir contains an include folder
# THis is not required, but the user should see a message, if it is missing
if [ ! -d $BUILD_DIR/include ]; then
	echo "INFO: Your build directory ($BUILD_DIR) does not contain an include folder. \
This means if your plugin has non-standard (not included in sourcemod) dependencies, these cannot be loaded"
else
	echo "Includes: "
	ls $BUILD_DIR/include
fi

test -e $COMPILE_DIR || mkdir $COMPILE_DIR

dir_before=$(pwd)
cd $BUILD_DIR
for sourcefile in $(find -name "*.sp")
do
	# Guard to prevent processing *.sp when no files in directory
	if [ ! -f "$sourcefile" ]; then
		echo "No files found for compilation"
		break;
	fi

	smxfile="`echo $sourcefile | sed -e 's/\.sp$/\.smx/'`"
	# Replace version in file
	if [ -n "${AUTO_VERSION_REPLACE+1}" ]; then
		echo "Replacing version string ..." 
		# Replace simple versions (${-version-}
		sed -i -e 's/${-version-}/'"$REPLACE_VERSION"'/g' $sourcefile

		# Insert complete define statement at placeholder
		# // #define GIT_PLUGIN_VERSION "xxx"
		sed -i -e 's/\/\/ ${-version-define-}/#define GIT_PLUGIN_VERSION "'"$REPLACE_VERSION"'"/g' $sourcefile
	fi

	# Invoke the compiler
	echo -e "Compiling $sourcefile ..."
	$SP_COMP_EXE $sourcefile -o $COMPILE_DIR/$smxfile -i $BUILD_DIR/include/ $additional_params
	RETVAL=$?
	if [ $RETVAL -ne 0 ]; then
		compile_failed
	fi
done
cd $dir_before

