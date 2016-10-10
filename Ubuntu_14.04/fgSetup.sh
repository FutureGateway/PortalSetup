#!/bin/bash
#
# Almost automatic FutureGateway setup script(*)
# This script can be executed once destination VM has been started
# Before execute the script, just provide the VM ip address (VMIP) and
# the client machine' SSH public key (SSHPUBKEY).
# During the execution destination VM sudo password may be required.
# To get the VM' sudo password, please contact the author or:
# sg-licence@ct.infn.it
#
# Author: Riccardo Bruno <riccardo.bruno@ct.infn.it>
#
# (*) Full automatic script can be obtained having a passwordless sudo user in 
#     the destination system. And providing SSH key exchange with cloud facilities
#     for instance with cloud-init
#     /etc/sudoers
#     <user>            ALL = (ALL) NOPASSWD: ALL
#

#
# Configure below the Git repository settings for each FutureGateway
# software package: PortalSetup, fgAPIServer, APIServerDaemon
# Each package requires: 
#  GIT<PKGNAME>_NAME  - name of the package in the repository
#  GIT<PKGNAME>_CLONE - name of the .git element in the clone URL
#  GIT<PKGNAME>_TAG   - specify here a specific branch/release
# 
GITBASE=https://github.com/indigo-dc                   # GitHub base repository endpoint
GITBASERAW=https://raw.githubusercontent.com/indigo-dc # GitHub base for raw content
GITPORTALSETUP_NAME="PortalSetup"                      # PortalSetup git path name
GITPORTALSETUP_CLONE="PortalSetup.git"                 # PortalSetup clone name
GITPORTALSETUP_TAG="master"                            # PortalSetup tag name
GITFGAPISERVER_NAME="fgAPIServer"                      # fgAPIServer git path name
GITFGAPISERVER_CLONE="fgAPIServer.git"                 # fgAPIServer clone name
GITFGAPISERVER_TAG="v0.0.5"                            # fgAPIServer tag name
GITFGAPISERVERDAEMON_NAME="APIServerDaemon"            # APIServerDaemon git path name
GITFGAPISERVERDAEMON_CLONE="APIServerDaemon.git"       # APIServerDaemon clone name
GITFGAPISERVERDAEMON_TAG="v0.0.5"                      # APIServerDaemin clone tag name  

OPTPASS=1
SCRIPTNAME=$(basename $0)
if [ "${1}" = "" ]; then
  OPTPASS=0
fi
VMUSER=$1
if [ "${2}" = "" ]; then
  OPTPASS=0
fi
VMIP=$2
if [ "${3}" = "" ]; then
  OPTPASS=0
fi
SSHPORT="$3"
if [ "${4}" = "" ]; then
  OPTPASS=0
fi
SSHPUBKEY="$4"
# Check for option PASS flag
if [ $OPTPASS -eq 0 ]; then
  echo "Usage $SCRIPTNAME <fgusername> <vm host/ip address> <ssh_port> <ssh_pubkey>"
  exit 1
fi
  
echo "#"
echo "# Executing FutureGateway general setup script ..."
echo "#"
echo "VMUSER   : '"$VMUSER"'"
echo "VMIP     : '"$VMIP"'"
echo "SSHPORT  : '"$SSHPORT"'"

SSHKOPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
TOMCATUSR="tomcat"
TOMCATPAS=$(openssl rand -hex 4)
MYSQL_RPAS=

# 1) Establish secure connection with the fg VM ssh-ing with: <VMUSER>@<VMIP>
if [ "${SSHPUBKEY}" != "" ]; then
  ssh -p $SSHPORT $SSHKOPTS -t $VMUSER@$VMIP "
SSHPUBKEY=\"$SSHPUBKEY\"
mkdir -p .ssh
echo \"\$SSHPUBKEY\" >> .ssh/authorized_keys
"
fi

# 2) Install mandatory packages
if [ "${MYSQL_RPAS}" != "" ]; then
  DBROOTPASS="$MYSQL_RPAS"
else
  DBROOTPASS="\\\"''\\\""
fi
ssh -p $SSHPORT $SSHKOPTS -t $VMUSER@$VMIP "
export DEBIAN_FRONTEND=\"noninteractive\"
sudo debconf-set-selections <<< \"mysql-server mysql-server/root_password password $DBROOTPASS\"
sudo debconf-set-selections <<< \"mysql-server mysql-server/root_password_again password $DBROOTPASS\"
sudo apt-get -y update
PKGS=\"wget \
openssh-client \
openssh-server \
mysql-server-5.6 \
mysql-server-core-5.6 \
mysql-client-5.6 \
mysql-client-core-5.6 \
openjdk-7-jdk \
build-essential \
mlocate \
unzip \
curl \
ruby-dev \
apache2 \
libapache2-mod-wsgi \
python-dev \
python-pip \
python-Flask \
python-flask-login \
python-crypto \
python-MySQLdb \
git \
ldap-utils \
openvpn \
screen \
jq\"
for pkg in \$PKGS; do
  sudo apt-get -y install \$pkg 
done
sudo pip install --upgrade flask-login
sudo service ssh restart
sudo service mysql restart
"

# 3) Install FGPortal
#
# !WARNING - Following file must be aligned with the latest version of setup_config.sh script
#
cat >setup_config.sh <<EOF
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
FGUSER=${VMUSER}                                 # User owning FutureGateway files
FGHOME=\$HOME                                    # This script could be executed as root; specify FG home here
FGREPO=\$FGHOME/FGRepo                           # Files could be cached into this repo directory
FGLOCATION=\$FGHOME/FutureGateway                # Location of the FutureGateway installation
FGENV=\$FGLOCATION/setenv.sh                     # FutureGateway environment variables

#
# setup_FGPortal.sh
#
TOMCATUSR=${TOMCATUSR}                              # TOMCAT username
TOMCATPAS=${TOMCATPAS}                              # TOMCAT password
SKIP_LIFERAY=0                                      # 0 - Installs Liferay
LIFERAY_VER=7                                       # Specify here the Liferay portal version: 6 or 7 (default)
LIFERAY_SDK_ON=1                                    # 0 - SDK will be not installed
LIFERAY_SDK_LOCATION=\$FGLOCATION                   # Liferay SDK will be placed here
MAVEN_ON=1                                          # 0 - Maven will be not installed (valid only if LIFERAY_SDK is on)
STARTUP_SYSTEM=1                                    # 0 - The portlal will be not initialized (unused yet)
TIMEZONE=\$(date +%Z)                               # Set portal timezone as system timezone (portal should operate at UTC)
SETUPDB=1                                           # 1 - Initialize Liferay DB
# Below MYSQL settings...                           # !!! WARNING enabling this flag
MYSQL_HOST=localhost                                # any existing DB will be dropped
MYSQL_PORT=3306
MYSQL_USER=lportal
MYSQL_PASS=lportal
MYSQL_DBNM=lportal
MYSQL_ROOT=root
MYSQL_RPAS=${MYSQL_RPAS}

#
# setup_JSAGA.sh
#
JSAGA_LOCATION=\$FGHOME/FutureGateway              # Liferay SDK will be placed here

#
# setup_OCCI.sh
#
USEFEDCLOUD=1                                      # Set to 1 for FedCloud setup script

#
# setup_GridEngine.sh
#
GEDIR=\$FGLOCATION/GridEngine
GELOG=\$GEDIR/log
GELIB=\$GEDIR/lib
SETUPUTDB=1                                         # 1 - Initialize UsersTracking DB
SETUPGRIDENGINEDAEMON=1                             # 1 - Configures GRIDENGINE Daemon
RUNDIR=\$FGHOME                                     # Normally placed at $FGHOME
GEMYSQL_HOST=localhost                              # Any existing DB will be dropped
GEMYSQL_PORT=3306
GEMYSQL_USER=tracking_user
GEMYSQL_PASS=usertracking
GEMYSQL_DBNM=userstracking

#
# Determine OS installer
#
BREW=\$(which brew >/dev/null 2>/dev/null)
APTGET=\$(which apt-get 2>/dev/null)
YUM=\$(which yum 2>/dev/null)

# Function that produces a timestamp
get_ts() {
 TS=\$(date +%y%m%d%H%M%S)
}

# Function that retrieves a file from FGRepo or download it
# from the web. The function takes three arguments:
#   \$1 - Source URL
#   \$2 - Destination path; (current dir if none; or only path to destination)
#   \$3 - Optional the name of the file (sometime source URL does not contain the name)
# FGREPO directory exists, because created by the preinstall_fg
get_file() {
  if [ "\${3}" != "" ]; then
    FILENAME="\${3}"
  else
    FILENAME=\$(basename \$1)
  fi
  if [ "\${2}" != "" ]; then
    DESTURL="\${2}"
  else
    DESTURL=\$(pwd)
  fi
  if [ -e "\${FGREPO}/\${FILENAME}" ]; then
    # The file exists in the cache
    echo "File \${FILENAME} exists in the cache" 
    cp "\${FGREPO}/\${FILENAME}" \$DESTURL/\$FILENAME
  else
    echo "File \${FILENAME} not in cache; retrieving it from the web"
    wget "\${1}" -O \$FGREPO/\$FILENAME 2>/dev/null
    RES=\$?
    if [ \$RES -ne 0 ]; then
      echo "FATAL: Unable to download from URL: \${1}"
      rm -f \$FGREPO/\$FILENAME
      exit 1
    fi 
    cp "\${FGREPO}/\${FILENAME}" \$DESTURL/\$FILENAME
  fi
}

#
# Function that replace the 1st matching occurrence of
# a pattern with a given line into the specified filename
#  \$1 # File to change
#  \$2 # Matching pattern that identifies the line
#  \$3 # New line content
#  \$4 # Optionally specify a suffix to keep a safe copy
replace_line() {
  file_name=\$1   # File to change
  pattern=\$2     # Matching pattern that identifies the line
  new_line=\$3    # New line content
  keep_suffix=\$4 # Optionally specify a suffix to keep a safe copy

  if [ "\$file_name" != "" -a -f \$file_name -a "\$pattern" != "" ]; then
      TMP=\$(mktemp)
      cp \$file_name \$TMP
      if [ "\$keep_suffix" != "" ]; then # keep a copy of replaced file
          cp \$file_name \$file_name"_"\$keep_suffix
      fi
      MATCHING_LINE=\$(cat \$TMP | grep -n "\$pattern" | head -n 1 | awk -F':' '{ print \$1 }' | xargs echo)
      if [ "\$MATCHING_LINE" != "" ]; then
          cat \$TMP | head -n \$((MATCHING_LINE-1)) > \$file_name
          printf "\$new_line\n" >> \$file_name 
          cat \$TMP | tail -n +\$((MATCHING_LINE+1)) >> \$file_name
      else
          echo "WARNING: Did not find '"\$pattern"' in file: '"\$file_name"'"
      fi
      rm -f \$TMP
  else
      echo "You must provide an existing filename and a valid pattern"
      return 1
  fi
}
EOF
scp $SSHKOPTS -P $SSHPORT setup_config.sh $VMUSER@$VMIP:
rm -f setup_config.sh
ssh -p $SSHPORT $SSHKOPTS -t $VMUSER@$VMIP "
[ -f FGRepo.tar.gz ] || wget http://sgw.indigo-datacloud.eu/fgsetup/FGRepo.tar.gz -O FGRepo.tar.gz
[ -f APIServerDaemon_lib.tar.gz ] || wget http://sgw.indigo-datacloud.eu/fgsetup/APIServerDaemon_lib.tar.gz -O APIServerDaemon_lib.tar.gz
wget $GITBASERAW/$GITPORTALSETUP_NAME/$GITPORTALSETUP_TAG/setup_FGPortal.sh -O setup_FGPortal.sh
chmod +x *.sh
./setup_FGPortal.sh
"

#3 Install JSAGA,GridEngine,rOCCI, fgService
ssh -p $SSHPORT $SSHKOPTS -t $VMUSER@$VMIP "
wget $GITBASERAW/$GITPORTALSETUP_NAME/$GITPORTALSETUP_TAG/setup_JSAGA.sh -O setup_JSAGA.sh
wget $GITBASERAW/$GITPORTALSETUP_NAME/$GITPORTALSETUP_TAG/setup_GridEngine.sh -O setup_GridEngine.sh
wget $GITBASERAW/$GITPORTALSETUP_NAME/$GITPORTALSETUP_TAG/setup_OCCI.sh -O setup_OCCI.sh
wget $GITBASERAW/$GITPORTALSETUP_NAME/$GITPORTALSETUP_TAG/setup_FGService.sh -O setup_FGService.sh
chmod +x setup_*.*
sudo ./setup_JSAGA.sh
sudo ./setup_GridEngine.sh
sudo ./setup_OCCI.sh # Script not really mature some tuning still necessary
sudo ./setup_FGService.sh
"

#4 fgAPIServer
if [ "${MYSQL_RPAS}" != "" ]; then
  SETUPFGAPIERVER_DB="mysql -u root -p$MYSQL_RPAS"
else
  SETUPFGAPIERVER_DB="mysql -u root"
fi
ssh -p $SSHPORT $SSHKOPTS -t $VMUSER@$VMIP "
source ~/.bash_profile
cd \$FGLOCATION
git clone -b $GITFGAPISERVER_TAG $GITBASE/$GITFGAPISERVER_CLONE
cd fgAPIServer
$SETUPFGAPIERVER_DB < fgapiserver_db.sql
"

#5 APIServerDaemon
TOSCAADAPTOR_GIT="https://github.com/csgf/jsaga-adaptor-tosca.git"
ROCCIADAPTOR_GIT="https://github.com/csgf/jsaga-adaptor-rocci.git"
cat > setup_APIServerDaemon.sh <<EOF
cd \$FGLOCATION
git clone -b $GITFGAPISERVERDAEMON_TAG $GITBASE/$GITFGAPISERVERDAEMON_CLONE
git clone $ROCCIADAPTOR_GIT
git clone $TOSCAADAPTOR_GIT
# Prepare lib dir
tar xvfz \$HOME/APIServerDaemon_lib.tar.gz -C \$FGLOCATION/APIServerDaemon/web/WEB-INF/
# Default JSON library works for java-8; in java-7 another jar is necessary
JVER=\$(java -version 2>&1 | head -n 1 | awk '{ print \$3 }' | sed s/\"//g | awk '{ print substr(\$1,1,3) }')
if [ "\${JVER}" = "1.7" ]; then
  echo "Changing JSON jar for java-7"
  mv \$FGLOCATION/APIServerDaemon/web/WEB-INF/lib/json-20150729.jar \$FGLOCATION/APIServerDaemon/web/WEB-INF/lib/json-20150729.jar_disabled
  wget http://central.maven.org/maven2/org/json/json/20140107/json-20140107.jar -O \$FGLOCATION/APIServerDaemon/web/WEB-INF/lib/json-20140107.jar  
fi
# Compile rocci adaptor
rm -rf \$FGLOCATION/APIServerDaemon/web/WEB-INF/lib/jsaga-adaptor-rocci*.jar
rm -rf \$FGLOCATION/APIServerDaemon/web/WEB-INF/lib/jsaga-adaptor-tosca*.jar
cd jsaga-adaptor-rocci
cd \$FGLOCATION/jsaga-adaptor-rocci
ant all
cp \$FGLOCATION/jsaga-adaptor-rocci/dist/jsaga-adaptor-rocci.jar \$FGLOCATION/APIServerDaemon/web/WEB-INF/lib
cp \$FGLOCATION/jsaga-adaptor-rocci/dist/jsaga-adaptor-rocci.jar \$FGLOCATION/jsaga-1.1.2/lib
# Compile tosca adaptor
cd \$FGLOCATION/jsaga-adaptor-tosca
mv \$FGLOCATION/jsaga-adaptor-tosca/build.xml \$FGLOCATION/jsaga-adaptor-tosca/build.xml_nb
mv \$FGLOCATION/jsaga-adaptor-tosca/build.xml_disabled \$FGLOCATION/jsaga-adaptor-tosca/build.xml
ant all
cp \$FGLOCATION/jsaga-adaptor-tosca/dist/jsaga-adaptor-tosca.jar \$FGLOCATION/APIServerDaemon/web/WEB-INF/lib
cp \$FGLOCATION/jsaga-adaptor-tosca/dist/jsaga-adaptor-tosca.jar \$FGLOCATION/jsaga-1.1.2/lib
# Compile APIServerDaemon
cd \$FGLOCATION/APIServerDaemon
ant all
cp \$FGLOCATION/APIServerDaemon/dist/APIServerDaemon.war \$CATALINA_HOME/webapps
cd \$FGLOCATION
EOF
scp $SSHKOPTS -P $SSHPORT setup_APIServerDaemon.sh $VMUSER@$VMIP:
rm -f setup_APIServerDaemon.sh
ssh -p $SSHPORT $SSHKOPTS -t $VMUSER@$VMIP "
source ~/.bash_profile
chmod +x setup_APIServerDaemon.sh
./setup_APIServerDaemon.sh
cp \$FGLOCATION/APIServerDaemon/dist/APIServerDaemon.war \$CATALINA_HOME/webapps
rm -f ./setup_APIServerDaemon.sh
"

#6 Customize DB and default app settings
cat > customize_DBApps.sh <<EOF
# Fix SSH connection issue on Ubuntu with JSAGA
sudo mkdir -p /etc/ssh/ssh_host_disabled
find  /etc/ssh/ -name 'ssh_host_*' | grep -v disabled | grep -v rsa | grep -v \_dsa | xargs -I{} sudo mv {} /etc/ssh/ssh_host_disabled/
# Use the correct application path
SQLCMD="update application_file set path='\$FGLOCATION/fgAPIServer/apps/sayhello' where app_id=2;"
mysql -h localhost -P 3306 -u fgapiserver -pfgapiserver_password fgapiserver -e "\$SQLCMD"
sudo adduser --disabled-password --gecos "" jobtest
RANDPASS=\$(openssl rand -base64 32 | head -c 12)
sudo usermod --password \$(echo "\$RANDPASS" | openssl passwd -1 -stdin) jobtest
SQLCMD="update infrastructure_parameter set pvalue='\$RANDPASS' where infra_id=1 and pname='password'";
mysql -h localhost -P 3306 -u fgapiserver -pfgapiserver_password fgapiserver -e "\$SQLCMD"
#IPADDR=\$(ifconfig eth0 | grep "inet " | awk -F'[: ]+' '{ print \$4 }')
IPADDR=localhost
SQLCMD="update infrastructure_parameter set pvalue='ssh://\$IPADDR:${SSHPORT}' where infra_id=1 and pname='jobservice'";
mysql -h localhost -P 3306 -u fgapiserver -pfgapiserver_password fgapiserver -e "\$SQLCMD"
# Take care of ssh keys (known_hosts)
mkdir -p \$HOME/.ssh
ssh-keyscan -H -p ${SSHPORT} -t rsa localhost >> \$HOME/.ssh/known_hosts
EOF
scp $SSHKOPTS -P $SSHPORT customize_DBApps.sh $VMUSER@$VMIP:
ssh -p $SSHPORT $SSHKOPTS -t $VMUSER@$VMIP "
source ~/.bash_profile
chmod +x customize_DBApps.sh
./customize_DBApps.sh
rm -f ./customize_DBApps.sh
sudo su - -c 'sudo cat >> /etc/ssh/sshd_config <<EOF2

#jobtest allow password auth.
Match User jobtest
    PasswordAuthentication yes
EOF2
'
sudo service ssh restart
"
rm -f ./customize_DBApps.sh

