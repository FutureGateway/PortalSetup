#!/bin/bash
#
# Setup script for the FutureGateway portal
#
# 17.09.2015 - riccardo.bruno@ct.infn.it
#


#
# Setup environment variables (default values)
#
. setup_config.sh                           # Load setup configuration variables
JSAGA_LOCATION=$FGHOME/FutureGateway        # Liferay SDK will be placed here

# pre installation steps
preinstall_js() {
  # 1st ensure that this script executes as su/root priviledges
  if [ $(id -u) != 0 ]; then
    echo "Please execute this script with sudo or as a root user"
    exit 1
  fi
  # FGENV
  if [ "${FGENV}" = "" ]; then
    echo "FATAL: \$FGENV environment variable must be set; please refer to the setup_FGPortal.sh script"
    return 1
  fi
  if [ ! -f $FGENV ]; then
    echo "FATAL: Unable to locate FutureGateway' setenv.sh environment file; please refer to the setup_FGPortal.sh script"
    return 1
  fi
    # Check if executing as root; in that case load environment
  if [ $(whoami) = "root" ]; then
    source $FGENV
  fi
  # Then check the consiststancy of several environment variables created by the setup_FGPortal.sh script
  # FGREPO
  if [ "${FGREPO}" = "" ]; then
    echo "FATAL: File repository not specified; please configure a path for it"
    return 1
  fi
  if [ ! -d $FGREPO ]; then
    echo "Not existing file repository; creating it at: $FGREPO"
    echo "This path is mandatory for JSAGA installation since the following files"
    echo "are needed by this installation and they have been directly taken from"
    echo "Oracle web site:"
    echo "    File                        JDK Ver."
    echo "    jce_policy-6.zip            JDK_1.6.x"
    echo "    UnlimitedJCEPolicyJDK7.zip  JDK_1.7.x"
    echo "    jce_policy-8.zip            JDK_1.8.x"
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
    echo "FATAL: \$FGSETUP environment variable must be set; please refer to the setup_FGPortal.sh script"
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
  SYSTEM=$(uname -s)
  if [ $SYSTEM = "Darwin" ]; then
    BREW=$(which brew >/dev/null 2>/dev/null)
    if [ "${BREW}" = "" ]; then
      echo "FATAL: brew is not present in your system; unable install"
      return 1
    fi
    # dos2unix is mandatory
    su - $FGUSER -c "${BREW} install dos2unix"
  elif [ $SYSTEM="Linux" ]; then
    APTGET=$(which apt-get >/dev/null 2>/dev/null)
    YUM=$(which yum >/dev/null 2>/dev/null)
    if [ "${APTGET}" = "" -a "${YUM}" = "" ]; then
      echo "FATAL: No supported installation facility found in your system (apt-get|yum); unable install"
      return 1
    fi
  fi
  # if YUM check for EPEL (mandatory)
  if [ "${YUM}" != "" ]; then
    EPEL=$(ls -1 /etc/yum.repos.d/*.repo | grep -i epel | wc -l)
    if [ $EPEL -eq 0 ]; then
      echo "FATAL: You need to install EPEL repo first: 'yum install epel-release # on CentOS7'"
      return 1
    fi  
  fi
  RUNDIR=$(cd $RUNDIR)
  # From now on the each installation phase assumes that the 
  # current directory is $FGLOCATION; during the installation
  # the current directory could be changed but always included
  # into a: cd .../newpath; cd - block statements
  # RUNDIR will contain the directory path at the setup execution
  # time
  cd $FGLOCATION
}

# installing UnlimitedCEPolicy
install_ultdcepolicy() {
  if [ -e $RUNDIR/.fgSetup ]; then
    SETUPCHK=$(cat $RUNDIR/.fgSetup | grep "ultdcepolicy")
  else
    SETUPCHK=""
  fi
  if [ "${SETUPCHK}" != "" ]; then
    echo "UnlimitedCEPolicy seems already installed; skipping this phase"
    return 0
  fi
  # Use the appropriate jar files
  if [ ${JVER:0:2} -eq 16 ]; then
    get_file http://download.oracle.com/otn-pub/java/jce_policy/6/jce_policy-6.zip
    cp jce/*.jar $JAVA_HOME/lib/
    rm -f jce_policy-6.zip
    rm -rf jce
  elif [ ${JVER:0:2} -eq 17 ]; then
    get_file http://download.oracle.com/otn-pub/java/jce/7/UnlimitedJCEPolicyJDK7.zip
    unzip UnlimitedJCEPolicyJDK7.zip
    cp UnlimitedJCEPolicy/*.jar $JAVA_HOME/lib/
    rm -f UnlimitedJCEPolicyJDK7.zip
    rm -rf UnlimitedJCEPolicy
  elif  [ ${JVER:0:2} -eq 18 ]; then
    get_file http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip
    unzip jce_policy-8.zip
    cp UnlimitedJCEPolicyJDK8/*.jar $JAVA_HOME/lib/
    rm -f jce_policy-8.zip
    rm -rf UnlimitedJCEPolicyJDK8
  else
    echo "Unsupported JAVA version: ${JVER}"
    echo "Please refer to the Oracle' web site to install this component by your own"
    echo "Once installed if you want to use this setup script to continue the installation"
    echo "please execute the following command: echo \"$XXXXXXXXXXXX   ultdcepolicy\" >> $RUNDIR/.fgSetup"
    echo "where XXXXXXXXXXXX string could be replaced by the output of the command: date +%y%m%d%H%M%S"
    echo "Then you can restart this setup script"
    return 1
  fi
  # Get appropriate Oracle' file
  # Install jars in the proper place
  # report to .fgSetup to track success
  get_ts
  echo "$TS   ultdcepolicy" >> $RUNDIR/.fgSetup
  return 0
}

# installing GSI
install_gsi() {
  if [ -e $RUNDIR/.fgSetup ]; then
    SETUPCHK=$(cat $RUNDIR/.fgSetup | grep "gsi")
  else
    SETUPCHK=""
  fi
  if [ "${SETUPCHK}" != "" ]; then
    echo "GSI seems already installed; skipping this phase"
    export JSAGA_HOME=${JSAGA_LOCATION}/jsaga-1.1.2
    export PATH=$PATH:$JSAGA_HOME/examples
    return 0
  fi
  if [ "${BREW}" != "" ]; then
    $FGREPO/lcg_CA.sh
    get_file https://dist.eugridpma.info/distribution/util/fetch-crl/fetch-crl-3.0.16.tar.gz
    tar xvfz fetch-crl-3.0.16.tar.gz
    cd fetch-crl-3.0.16
    make install
    cd -
    fetch-crl
    su - $FGUSER -c "${BREW} install voms"
  elif [ "${APTGET}" != "" ]; then
    wget -q -O - https://dist.eugridpma.info/distribution/igtf/current/GPG-KEY-EUGridPMA-RPM-3 | apt-key add -
    deb http://repository.egi.eu/sw/production/cas/1/current egi-igtf core
    $APTGET update
    $APTGET install -y ca-policy-egi-core
    get_file wget https://dist.eugridpma.info/distribution/util/fetch-crl/fetch-crl-3.0.16.tar.gz
    tar xvfz fetch-crl-3.0.16.tar.gz
    cd fetch-crl-3.0.16
    make install
    cd -
    fetch-crl
    $APTGET install -y voms-clients
  elif [ "${YUM}" != "" ]; then
    cat > /etc/yum.repos.d/EGI-trustanchors.repo <<EOF
[EGI-trustanchors]
name=EGI-trustanchors
baseurl=http://repository.egi.eu/sw/production/cas/1/current/
gpgkey=http://repository.egi.eu/sw/production/cas/1/GPG-KEY-EUGridPMA-RPM-3
gpgcheck=1
enabled=1
EOF
    $YUM install -y ca-policy-egi-core
    $YUM install -y fetch-crl
    fetch-crl
    $YUM install -y voms-clients
  else
    echo "FATAL: Unsupported system: $SYSTEM"
    return 1
  fi
  # report to .fgSetup to track success
  get_ts
  echo "$TS   gsi" >> $RUNDIR/.fgSetup
  return 0
}

# installing JSAGA
install_js() {
  if [ -e $RUNDIR/.fgSetup ]; then
    SETUPCHK=$(cat $RUNDIR/.fgSetup | grep "jsaga")
  else
    SETUPCHK=""
  fi
  if [ "${SETUPCHK}" != "" ]; then
    echo "JSAGA seems already installed; skipping this phase"
    export JSAGA_HOME=${JSAGA_LOCATION}/jsaga-1.1.2
    export PATH=$PATH:$JSAGA_HOME/examples
    return 0
  fi
  echo "Installing JSAGA"
  # get JSAGA installer file
  get_file http://maven.in2p3.fr/fr/in2p3/jsaga/jsaga-installer/1.1.2/jsaga-installer-1.1.2-bin.zip
  unzip jsaga-installer-1.1.2-bin.zip
  rm -f jsaga-installer-1.1.2-bin.zip
  cd jsaga-1.1.2
  chmod +x ./post-install.sh
  ./post-install.sh 
cat >> $FGENV <<EOF
# JSAGA environment
export JSAGA_HOME=${JSAGA_LOCATION}/jsaga-1.1.2
export PATH=\$PATH:${JSAGA_HOME}/examples
export CLASSPATH=\$CLASSPATH:\$(find \$JSAGA_HOME/lib -name '*.jar' | awk 'BEGIN{ c="" }{ printf("%c%s",c,\$1); c=":" }')
EOF
  cd -
  # report to .fgSetup to track success
  get_ts
  echo "$TS   jsaga" >> $RUNDIR/.fgSetup
  return 0
}

# post installation steps
postinstall_js() {
  # go back to the RUNDIR
  cd $RUNDIR
  # Final message
  echo "Installation script accomplished"
  echo "WARNING: Please from now on use another terminal since new enviornment"
  echo "         environment settings are now available, or you may source first"
  echo "         the configuration file: ${FGENV}"
  echo ""
  # report to .fgSetup to track success  
  get_ts
  echo "$TS   jsend" >> $RUNDIR/.fgSetup
  return 0
}

# uninstall script
js_uninstall() {
  echo "JSAGA uninstallation not supported yet; you may uninstall the whole FG system instead;"
  echo "to do this, please refer to the setup_FGPortal.sh script"
  echo "Once you remove the FG system, you have also to remove manually the following items:"
  echo "   GSI"
  echo "     voms settings"
  echo "     fetch-crl"
  echo "     lcg_CA/egi-thrustanchors"
  echo "   JAVA"
  echo "     jce-policy"
}

##
## Script execution
##
if [ "${1}" != "" ]; then
  if [ "${1}" = "-u" ]; then
    echo "Uninstalling JSAGA ..."
    js_uninstall
  elif [ "${1}" = "-h" -o "${1}" = "--help" ]; then
    SNAME=$(basename $0)
    echo "Usage: ${SNAME} [-u] [-h|--help]"
    echo "Execute without arguments to install JSAGA"
    echo "Use -h or --help to show this page"
    echo ""
    echo "This script will install JSAGA libraries and perform"
    echo "several additional actions to link JSAGA with the"
    echo "FutureGateway platform"
    echo ""
    exit 0
  else
    echo "FATAL: Unrecognized option: \"${1}\""
    exit 1
  fi
else
  preinstall_js        && \
  install_ultdcepolicy && \
  install_gsi          && \
  install_js           && \
  postinstall_js
fi

exit 0
