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
preinstall_occi() {
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
  # sudo/root users do not have the FutureGateway environment
  source $FGENV
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

# install OCCI Client interface
install_occi() {
  if [ -e $RUNDIR/.fgSetup ]; then
    SETUPCHK=$(cat $RUNDIR/.fgSetup | grep "occi")
  else
    SETUPCHK=""
  fi
  if [ "${SETUPCHK}" != "" ]; then
    echo "OCCI seems already installed; skipping this phase"
    return 0
  fi
  echo "Installing OCCI"
  # installation foresees a different process for each supported architecture
    if [ $SYSTEM = "Darwin" ]; then
    # MacOS X
    RUBY=$(which ruby)
    if [ "${RUBY}" = "" ]; then
        $BREW isntall ruby
        RES=$?
        if [ $RES -ne 0 ]; then
            echo "FATAL: Your OCCI-client could not be installed."
            echo "       Please try to fix your ruby/gem environment first."
            return 1
        fi
    fi
    GEM=$(which gem)
    fi [ "${GEM}" = "" ]; then
        echo "FATAL: Unhespected ruby installation without gem"
        echo "       Please try to fix your environment first."
        return 1    
    fi
    $GEM install occi-cli
    RES=$?
    if [ $RES -ne 0 ]; then
        echo "FATAL: Your OCCI-client could not be installed."
        echo "       Please try to fix your ruby/gem environment first."
    fi
  elif [ $SYSTEM="Linux" ]; then
    if [ "${APTGET}" != "" ]; then
       # Debian system
       RUBY=$(which ruby)
       if [ "${RUBY}" = "" ]; then
           $APTGET isntall ruby
           RES=$?
           if [ $RES -ne 0 ]; then
               echo "FATAL: Your OCCI-client could not be installed."
               echo "       Please try to fix your ruby/gem environment first."
               return 1
           fi
       fi
       GEM=$(which gem)
       fi [ "${GEM}" = "" ]; then
           echo "FATAL: Unhespected ruby installation without gem"
           echo "       Please try to fix your environment first."
           return 1    
       fi
       $GEM install occi-cli
       RES=$?
       if [ $RES -ne 0 ]; then
           echo "FATAL: Your OCCI-client could not be installed."
           echo "       Please try to fix your ruby/gem environment first."
       fi
    elif [ "${YUM}" != "" ]; then
       # Enterprise Linux System
       get_file http://repository.egi.eu/community/software/rocci.cli/4.2.x/releases/repofiles/sl-6-x86_64.repo /etc/yum.repos.d rocci-cli.repo
       yum install -y occi-cli
       ln -s /opt/occi-cli/bin/occi /usr/bin/occi
    else
      echo "FATAL: No supported installation facility found in your system (apt-get|yum); unable install"
      return 1
    fi
  fi
  # report to .fgSetup to track success    
  get_ts
  echo "$TS  occi" >> $RUNDIR/.fgSetup
}

# post installation steps
postinstall_occi() {
  # go back to the RUNDIR
  cd $RUNDIR
  # Final message
  echo "Installation script accomplished"
  echo ""
  # report to .fgSetup to track success  
  get_ts
  echo "$TS   occiend" >> $RUNDIR/.fgSetup
  return 0
}

# uninstall script
occi_uninstall() {
  echo "WARNING: Sorry, OCCI uninstallation not supported yet"
}

##
## Script execution
##
if [ "${1}" != "" ]; then
  if [ "${1}" = "-u" ]; then
    echo "Uninstalling OCCI ..."
    occi_uninstall
  elif [ "${1}" = "-h" -o "${1}" = "--help" ]; then
    SNAME=$(basename $0)
    echo "Usage: ${SNAME} [-u] [-h|--help]"
    echo "Execute without arguments to install OCCI client"
    echo "Use -h or --help to show this page"
    echo ""
    echo "This script will install OCCI client"
    exit 0
  else
    echo "FATAL: Unrecognized option: \"${1}\""
    exit 1
  fi
else
  preinstall_occi   && \
  install_occi      && \
  postinstall_occi
fi

exit 0
