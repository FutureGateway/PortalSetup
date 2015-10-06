#!/bin/bash
#
# Setup script for the FutureGateway portal
#
# 17.09.2015 - riccardo.bruno@ct.infn.it
#


#
# Setup environment variables (default values)
#
GEDIR=$FGLOCATION/GridEngine
GELOG=$GEDIR/log
GELIB=$GEDIR/lib

SETUPDB=1                                           # 1 - Initialize UsersTracking DB
# Below MYSQL settings...                           # !!! WARNING enabling this flag
MYSQL_HOST=localhost                                # any existing DB will be dropped
MYSQL_PORT=3306
MYSQL_USER=tracking_user
MYSQL_PASS=usertracking
MYSQL_DBNM=userstracking
MYSQL_ROOT=root
MYSQL_RPAS=

# This file contains common variables for setup_* scripts it may be used to override above settings
. setup_config.sh

# pre installation steps
preinstall_ge() {
  # FGENV
  if [ "${FGENV}" = "" ]; then
    echo "FATAL: \$FGENV environment variable must be set; please refer to the setup_FGPortal.sh script"
    return 1
  fi
  if [ ! -f $FGENV ]; then
    echo "FATAL: Unable to locate FutureGateway' setenv.sh environment file; please refer to the setup_FGPortal.sh script"
    return 1
  fi
  # Then check the consiststancy of several environment variables created by the setup_FGPortal.sh script
  # FGREPO
  if [ "${FGREPO}" = "" ]; then
    echo "FATAL: File repository not specified; please configure a path for it"
    return 1
  fi
  if [ ! -d $FGREPO ]; then
    mkdir -p $FGREPO
    return 1
  fi
  # RUNDIR
  if [ "${RUNDIR}" = "" ]; then
    echo "FATAL: \$RUNDIR environment variable must be set; please refer to the setup_FGPortal.sh script"
    return 1
  fi
  if [ ! -d $RUNDIR ]; then
    echo "FATAL: Unable to locate directory from where setup_FGPortal.sh script has been executed"
    return 1
  fi
  # FGSETUP
  if [ "${FGSETUP}" = "" ]; then
    echo "FATAL: \$FGSETUP environment variable must be set; please refer to the setup_FGPortal.sh script"
    return 1
  fi
  if [ ! -f $FGSETUP ]; then
    echo "FATAL: Unable to locate setup tracking file for setup_FGPortal.sh script"
    return 1
  fi
  # FGLOCATION
  if [ "${FGLOCATION}" = "" ]; then
    echo "FATAL: \$FGLOCATION environment variable must be set; please refer to the setup_FGPortal.sh script"
    return 1
  fi
  if [ ! -d $FGLOCATION ]; then
    echo "FATAL: Unable to locate FutureGateway installation directory; please refer to the setup_FGPortal.sh script"
    return 1
  fi
  # JAVA_HOME
  if [ "${JAVA_HOME}" = "" ]; then
    echo "FATAL: \$JAVA_HOME environment variable must be set; please refer to the setenv.sh environment file"
    return 1
  fi
  if [ ! -d $JAVA_HOME ]; then
    echo "FATAL: Unable to locate Java' home directory, please refer to your JAVA installation settings"
    return 1
  fi
  # Determine JAVA version
  JVER=$(java -version 2>&1 | awk -F'"' '{ print $2 }' | awk -F"_" '{ print $1 }' | sed s/'\.'//g)
  if [ "${JVER}" = "" ]; then
    echo "FATAL: Unrecognized java version; is it installed in your system?"
    return 1
  fi 
  # Database pre-requisites
  if [ $SETUPDB -ne 0 ]; then
    MYSQL=$(which mysql)
    if [ "${MYSQL}" = "" ]; then
      echo "FATAL: Specifying SETUPDB option; the system must have mysql client"
      return 1
    fi
    if [ "${MYSQL_ROOT}" = "" ]; then
      echo "FATAL: Specifying SETUPDB option; you must provide mysql ROOT user"
      return 1
    fi
    if [ "${MYSQL_RPAS}" != "" ]; then
      PASSOPT="-p${MYSQL_RPAS}"
    else
      PASSOPT=
    fi
    $MYSQL -u${MYSQL_ROOT} $PASSOPT -s  -N -e "select now();" > /dev/null
    RES=$?
    rm -f /tmp/lportal_create.sql
    if [ $RES -ne 0 ]; then
      echo "FATAL: Unable to connect as root to the database"
      return 1
    fi
  fi
  CURRDIR=$PWD
  # From now on the each installation phase assumes that the 
  # current directory is $FGLOCATION; during the installation
  # the current directory could be changed but always included
  # into a: cd .../newpath; cd - block statements
  # RUNDIR will contain the directory path at the setup execution
  # time
  cd $FGLOCATION
}

# installing GridEngine
install_ge() {
  if [ -e $RUNDIR/.fgSetup ]; then
    SETUPCHK=$(cat $RUNDIR/.fgSetup | grep "gridengine")
  else
    SETUPCHK=""
  fi
  if [ "${SETUPCHK}" != "" ]; then
    echo "GridEngine seems already installed; skipping this phase"
    CLASSPATH=$CLASSPATH:$(find $GELIB -name '*.jar' | awk 'BEGIN{ i=0 }{ printf("%s%s",(i++)==0?"":":",$1); }')
    return 0
  fi
  echo "Installing GridEngine"
  mkdir -p $GEDIR/log
  cd GridEngine
  get_file http://grid.ct.infn.it/csgf/binaries/GridEngine_v1.5.10.zip
  cat > ziplist <<EOF
lib/antlr-2.7.6.jar \
lib/commons-collections-3.1.jar \
lib/commons-fileupload-1.2.2.jar \
lib/commons-io-2.0.1.jar \
lib/commons-logging-1.1.jar \
lib/dom4j-1.6.1.jar \
lib/gridengine-threadpools-1.0.0.jar \
lib/hibernate3.jar \
lib/hibernate-jpa-2.0-api-1.0.1.Final.jar \
lib/hsql.jar \
lib/jsaga-job-management-1.5.10.jar \
lib/jta-1.1.jar \
lib/jtds.jar
EOF
  unzip -o GridEngine_v1.5.10.zip $(cat ziplist)
  rm -f ziplist
  rm -f GridEngine_v1.5.10.zip
  CLASSPATH=$CLASSPATH:$(find $GELIB -name '*.jar' | awk 'BEGIN{ i=0 }{ printf("%s%s",(i++)==0?"":":",$1); }')
  cat >>${FGENV} <<EOF
# GridEngine configuration (!) do not remove or modify this and the following line                                # [GridEngine] 
CLASSPATH=\$CLASSPATH:\$(find ${GELIB} -name '*.jar' | awk 'BEGIN{ i=0 }{ printf("%s%s",(i++)==0?"":":",\$1); }') # [GridEngine]
EOF
  cat > GridEngineLogConfig.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE log4j:configuration SYSTEM "log4j.dtd">
<log4j:configuration xmlns:log4j="http://jakarta.apache.org/log4j/">
	<appender name="APPENDER_OUT" class="org.apache.log4j.ConsoleAppender">
		<layout class="org.apache.log4j.PatternLayout">
			<!-- Print the date in ISO 8601 format -->
			<param name="ConversionPattern" value="%d{yyyy-MM-dd HH:mm:ss} [%t] %-5p %c{1} %x - %m%n" />
		</layout>
	</appender>
	<appender name="APPENDER_FILE" class="org.apache.log4j.DailyRollingFileAppender">
		<param name="File" value="${GELOG}/GridEngineLog.log" />
		<param name="DatePattern" value="'.'yyyy-MM-dd" />
		<param name="Append" value="true"/>
		<!--param name="Threshold" value="DEBUG" /-->
		<layout class="org.apache.log4j.PatternLayout">
			<param name="ConversionPattern" value="%d{yyyy-MM-dd HH:mm:ss,SSS} [%t] %-5p %c{1} %x - %m%n" />
		</layout>
	</appender>
	<appender name="ASYNCH" class="org.apache.log4j.AsyncAppender">
		<appender-ref ref="APPENDER_FILE" />
		<appender-ref ref="APPENDER_OUT" />
	</appender>
	<category name="it.infn.ct.GridEngine" additivity="false">
		<priority value="debug" />
		<appender-ref ref="ASYNCH" />
	</category>
</log4j:configuration>
EOF
  cd -
  # report to .fgSetup to track success
  get_ts
  echo "$TS gridengine" >> $RUNDIR/.fgSetup
  return 0
}

# installing UsersTracking Database
install_utdb() {
  if [ -e $RUNDIR/.fgSetup ]; then
    SETUPCHK=$(cat $RUNDIR/.fgSetup | grep "geutdb")
  else
    SETUPCHK=""
  fi
  if [ "${SETUPCHK}" != "" ]; then
    echo "GridEngine' users tracking database seems already installed; skipping this phase"
    return 0
  fi
  echo "Installing GridEngine' users tracking database"
  get_file https://raw.githubusercontent.com/csgf/grid-and-cloud-engine/master/UsersTrackingDB/UsersTrackingDB.sql
  if [ $SETUPDB -ne 0 ]; then
    MYSQL=$(which mysql)
    if [ "${MYSQL}" = "" ]; then
      echo "FATAL: Specifying SETUPDB option; the system must have mysql client"
      return 1
    fi
    if [ "${MYSQL_ROOT}" = "" ]; then
      echo "FATAL: Specifying SETUPDB option; you must provide mysql ROOT user"
      return 1
    fi
    if [ "${MYSQL_RPAS}" != "" ]; then
      PASSOPT="-p${MYSQL_RPAS}"
    else
      PASSOPT=
    fi
    $MYSQL -u${MYSQL_ROOT} $PASSOPT < UsersTrackingDB.sql
    RES=$?
    rm -f UsersTrackingDB.sql
    if [ $RES -ne 0 ]; then
      echo "FATAL: Unable to connect as root to the database"
      return 1
    fi
  fi
  # Now test connection
  $MYSQL -u${MYSQL_USER} -p${MYSQL_PASS} ${MYSQL_DBNM} -s -N -e "select now()" > /dev/null
  RES=$?
  if [ $RES -ne 0 ]; then
    echo "FATAL: Not connected to the GridEngine' users tracking database"
    return 1
  else
    echo "Successfully connected to GridEngine' users tracking database"
  fi
  # report to .fgSetup to track success
  get_ts
  echo "$TS geutdb" >> $RUNDIR/.fgSetup
  return 0  
}

# post installation steps
postinstall_ge() {
  # go back to the CURRDIR
  cd $CURRDIR
  # Final message
  echo "Installation script accomplished"
  echo "WARNING: Please from now on use another terminal since new enviornment"
  echo "         environment settings are now available, or you may source first"
  echo "         the configuration file: ${FGENV}"
  echo ""
  # report to .fgSetup to track success  
  get_ts
  echo "$TS geend" >> $RUNDIR/.fgSetup
  return 0
}

# uninstall script
ge_uninstall() {
  echo "GridEngine will be removed form your system"
  rm -rf $GEDIR
  # Get rid of environment change; (CLASSPATH)
  cp ${FGENV} ${FGENV}_orig
  cat ${FGENV}_orig | grep -v "\[GridEngine\]" > ${FGENV}
  rm -f ${FGENV}_orig
  # Get rid of setup track
  cp $RUNDIR/.fgSetup $RUNDIR/.fgSetup_orig
  cat $RUNDIR/.fgSetup_orig  | grep -v gridengine > $RUNDIR/.fgSetup_orig1
  cat $RUNDIR/.fgSetup_orig1 | grep -v geutdb     > $RUNDIR/.fgSetup_orig2
  cat $RUNDIR/.fgSetup_orig2 | grep -v geend      > $RUNDIR/.fgSetup
  rm -f $RUNDIR/.fgSetup_orig $RUNDIR/.fgSetup_orig1 $RUNDIR/.fgSetup_orig2
  # Get rid of GridEngine' UsersTracking database
  MYSQL=$(which mysql)
  if [ "${MYSQL}" = "" ]; then
    echo "FATAL: Specifying SETUPDB option; the system must have mysql client"
    return 1
  fi
  if [ "${MYSQL_ROOT}" = "" ]; then
    echo "FATAL: Specifying SETUPDB option; you must provide mysql ROOT user"
    return 1
  fi
  if [ "${MYSQL_RPAS}" != "" ]; then
    PASSOPT="-p${MYSQL_RPAS}"
  else
    PASSOPT=
  fi
  $MYSQL -u${MYSQL_ROOT} $PASSOPT -N -s -e 'drop database userstracking;'
  RES=$?
  if [ $RES -ne 0 ]; then
    echo "FATAL: Unable to drop GridEngine' UsersTracking database"
    return 1
  fi
  return 0
}

##
## Script execution
##
if [ "${1}" != "" ]; then
  if [ "${1}" = "-u" ]; then
    echo "Uninstalling GridEngine ..."
    ge_uninstall
  elif [ "${1}" = "-h" -o "${1}" = "--help" ]; then
    SNAME=$(basename $0)
    echo "Usage: ${SNAME} [-u] [-h|--help]"
    echo "Execute without arguments to install GridEngine"
    echo "Use -h or --help to show this page"
    echo ""
    echo "This script will install GridEngine"
    exit 0
  else
    echo "FATAL: Unrecognized option: \"${1}\""
    exit 1
  fi
else
  preinstall_ge        && \
  install_ge           && \
  install_utdb         && \
  postinstall_ge
fi
exit 0

