#!/bin/bash
#
# Setup configuration script for any FutureGateway setup script
#
# 01.10.2015 - riccardo.bruno@ct.infn.it
#
# This file contains common variables for setup_* scripts it may be used to override 
# values defined inside setup settings

#
# Setup configuration variables
#
# Uncomment and change one ot these values to override default settings
# specified inside each setup_* scripts

#
# Common values; FG user, FG user directory, FG file repo, FG home dir, FG environment
#
FGUSER=Macbook                              # User owning FutureGateway files
FGHOME=$HOME/Documents                      # This script could be executed as root; specify FG home here
FGREPO=$FGHOME/FGRepo                       # Files could be cached into this repo directory
FGLOCATION=$FGHOME/FutureGateway            # Location of the FutureGateway installation
FGENV=$FGLOCATION/setenv.sh                 # FutureGateway environment variables

#
# setup_FGPortal.sh
#
#TOMCATUSR="tomcat"                                  # TOMCAT username
#TOMCATPAS="tomcat"                                  # TOMCAT password
#LIFERAY_SDK_ON=1                                    # 0 - SDK will be not installed
#LIFERAY_SDK_LOCATION=$HOME/Documents/FutureGateway  # Liferay SDK will be placed here
#MAVEN_ON=1                                          # 0 - Maven will be not installed (valid only if LIFERAY_SDK is on)
#STARTUP_SYSTEM=1                                    # 0 - The portlal will be not initialized (unused yet)
#TIMEZONE="GMT+1"                                    # Set portal timezone
#SETUPDB=1                                           # 1 - Initialize Liferay DB
# Below MYSQL settings...                           # !!! WARNING enabling this flag
#MYSQL_HOST=localhost                                # any existing DB will be dropped
#MYSQL_PORT=3306
#MYSQL_USER=lportal
#MYSQL_PASS=lportal
#MYSQL_DBNM=lportal
#MYSQL_ROOT=root
#MYSQL_RPAS=

#
# setup_JSAGA.sh
#
#JSAGA_LOCATION=$FGHOME/FutureGateway        # Liferay SDK will be placed here

#
# setup_OCCI.sh
#
# No specific environment exists for this script

#
# setup_GridEngine.sh
#
#GEDIR=$FGLOCATION/GridEngine
#GELOG=$GEDIR/log
#GELIB=$GEDIR/lib



# Function that produces a timestamp
get_ts() {
 TS=$(date +%y%m%d%H%M%S)
}

# Function that retrieves a file from FGRepo or download it
# from the web. The function takes three arguments:
#   $1 - Source URL
#   $2 - Destination path; (current dir if none; or only path to destination)
#   $3 - Optional the name of the file (sometime source URL does not contain the name)
# FGREPO directory exists, because created by the preinstall_fg
get_file() {
  if [ "${3}" != "" ]; then
    FILENAME="${3}"
  else
    FILENAME=$(basename $1)
  fi
  if [ "${2}" != "" ]; then
    DESTURL="${2}"
  else
    DESTURL=$(pwd)
  fi
  if [ -e "${FGREPO}/${FILENAME}" ]; then
    # The file exists in the cache
    echo "File ${FILENAME} exists in the cache" 
    cp "${FGREPO}/${FILENAME}" $DESTURL/$FILENAME
  else
    echo "File ${FILENAME} not in cache; retrieving it from the web"
    wget "${1}" -O $FGREPO/$FILENAME 2>/dev/null
    RES=$?
    if [ $RES -ne 0 ]; then
      echo "FATAL: Unable to download from URL: ${1}"
      rm -f $FGREPO/$FILENAME
      exit 1
    fi 
    cp "${FGREPO}/${FILENAME}" $DESTURL/$FILENAME
  fi
}


