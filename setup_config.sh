#!/bin/bash
#
# Setup configuration script for any FutureGateway setup script
#
# 01.10.2015 - riccardo.bruno@ct.infn.it
#

#
# Setup configuration variables 
#
FGUSER=Macbook                              # User owning FutureGateway files
FGHOME=$HOME/Documents                      # This script could be executed as root; specify FG home here
FGREPO=$FGHOME/FGRepo                       # Files could be cached into this repo directory
FGLOCATION=$FGHOME/FutureGateway            # Location of the FutureGateway installation
FGENV=$FGLOCATION/setenv.sh                 # FutureGateway environment variables

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


