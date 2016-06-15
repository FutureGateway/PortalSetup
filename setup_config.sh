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
load_common() {
  LOAD_FUNCTION=$LOAD_FUNCTION" common"
  FGUSER=$(whoami)                            # User owning FutureGateway files
  FGHOME=$HOME/                               # This script could be executed as root; specify FG home here
  FGREPO=$FGHOME/FGRepo                       # Files could be cached into this repo directory
  FGLOCATION=$FGHOME/FutureGateway            # Location of the FutureGateway installation
  FGENV=$FGLOCATION/setenv.sh                 # FutureGateway environment variables
}

#
# setup_FGPortal.sh
#
load_fgportal() {
  LOAD_FUNCTION=$LOAD_FUNCTION" fgportal"
  #TOMCATUSR="tomcat"                                  # TOMCAT username
  #TOMCATPAS=$(openssl rand -hex 4)'                   # TOMCAT password
  #SKIP_LIFERAY=0                                      # 0 - Installs Liferay
  #LIFERAY_VER=7                                       # Specify here the Liferay portal version: 6 or 7 (default)
  #LIFERAY_SDK_ON=1                                    # 0 - SDK will be not installed
  #LIFERAY_SDK_LOCATION=$FGLOCATION                    # Liferay SDK will be placed here
  #MAVEN_ON=1                                          # 0 - Maven will be not installed (valid only if LIFERAY_SDK is on)
  #STARTUP_SYSTEM=1                                    # 0 - The portlal will be not initialized (unused yet)
  #TIMEZONE=$(date +%Z)                                # Set portal timezone as system timezone (portal should operate at UTC)
  #SETUPDB=1                                           # 1 - Initialize Liferay DB
  # Below MYSQL settings...                           # !!! WARNING enabling this flag
  #MYSQL_HOST=localhost                                # any existing DB will be dropped
  #MYSQL_PORT=3306
  #MYSQL_USER=lportal
  #MYSQL_PASS=lportal
  #MYSQL_DBNM=lportal
  #MYSQL_ROOT=root
  #MYSQL_RPAS=
}

#
# setup_JSAGA.sh
#
load_jsaga() {
  LOAD_FUNCTION=$LOAD_FUNCTION" jsaga"
  #JSAGA_LOCATION=$FGHOME/FutureGateway        # Liferay SDK will be placed here
  #FGENV=$FGLOCATION/sentenv.sh
}

#
# setup_OCCI.sh
#
load_occi() {
  LOAD_FUNCTION=$LOAD_FUNCTION" occi"
  #USEFEDCLOUD=1                                     # Set to 1 for FedCloud setup script
}

#
# setup_GridEngine.sh
#
load_gridengine() {
  LOAD_FUNCTION=$LOAD_FUNCTION" gridengine"
  #GEDIR=$FGLOCATION/GridEngine
  #GELOG=$GEDIR/log
  #GELIB=$GEDIR/lib
  #SETUPUTDB=1                                         # 1 - Initialize UsersTracking DB
  #SETUPGRIDENGINEDAEMON=1                             # 1 - Configures GRIDENGINE Daemon
  #RUNDIR=$FGHOME                                      # Normally placed at $FGHOME
  #GEMYSQL_HOST=localhost                              # Any existing DB will be dropped
  #GEMYSQL_PORT=3306
  #GEMYSQL_USER=tracking_user
  #GEMYSQL_PASS=usertracking
  #GEMYSQL_DBNM=userstracking
}

#
# load setup helper functions
#
load_functions() {
  LOAD_FUNCTION=$LOAD_FUNCTION" functions"
  #
  # Determine OS installer
  #
  BREW=$(which brew >/dev/null 2>/dev/null)
  APTGET=$(which apt-get 2>/dev/null)
  YUM=$(which yum 2>/dev/null)

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

  #
  # Function that replace the 1st matching occurrence of
  # a pattern with a given line into the specified filename
  #  $1 # File to change
  #  $2 # Matching pattern that identifies the line
  #  $3 # New line content
  #  $4 # Optionally specify a suffix to keep a safe copy
  replace_line() {
    file_name=$1   # File to change
    pattern=$2     # Matching pattern that identifies the line
    new_line=$3    # New line content
    keep_suffix=$4 # Optionally specify a suffix to keep a safe copy

    if [ "$file_name" != "" -a -f $file_name -a "$pattern" != "" ]; then
      TMP=$(mktemp)
      cp $file_name $TMP
      if [ "$keep_suffix" != "" ]; then # keep a copy of replaced file
        cp $file_name $file_name"_"$keep_suffix
      fi
      MATCHING_LINE=$(cat $TMP | grep -n "$pattern" | head -n 1 | awk -F':' '{ print $1 }' | xargs echo)
      if [ "$MATCHING_LINE" != "" ]; then
        cat $TMP | head -n $((MATCHING_LINE-1)) > $file_name
        printf "$new_line\n" >> $file_name
        cat $TMP | tail -n +$((MATCHING_LINE+1)) >> $file_name
      else
        echo "WARNING: Did not find '"$pattern"' in file: '"$file_name"'"
      fi
      rm -f $TMP
    else
      echo "You must provide an existing filename and a valid pattern"
      return 1
    fi
  }
}

#
# Take the proper action accordingly to the given parameter
#
case "$1" in
  "common")
    load_common
    ;;
  "fgportal")
    load_fgportal
    ;;
  "jsaga")
    load_jsaga
    ;;
  "occi")
    load_occi
    ;;
  "gridengine")
    load_gridengine
    ;;
  "functions")
    load_functions
    ;;
  *)
    load_common
    load_fgportal
    load_jsaga
    load_occi
    load_gridengine
    load_functions
esac
