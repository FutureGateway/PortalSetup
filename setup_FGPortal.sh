#!/bin/bash
#
# Setup script for the FutureGateway portal
#
# 14.09.2015 - riccardo.bruno@ct.infn.it
#

#
# Setup environment variables (default values)
#
TOMCATUSR="tomcat"                                  # TOMCAT username
TOMCATPAS="tomcat"                                  # TOMCAT password
LIFERAY_SDK_ON=1                                    # 0 - SDK will be not installed
LIFERAY_SDK_LOCATION=$HOME/Documents/FutureGateway  # Liferay SDK will be placed here
MAVEN_ON=1                                          # 0 - Maven will be not installed (valid only if LIFERAY_SDK is on)
STARTUP_SYSTEM=1                                    # 0 - The portlal will be not initialized (unused yet)
TIMEZONE="GMT+1"                                    # Set portal timezone
SETUPDB=1                                           # 1 - Initialize Liferay DB
# Below MYSQL settings...                           # !!! WARNING enabling this flag
MYSQL_HOST=localhost                                # any existing DB will be dropped
MYSQL_PORT=3306
MYSQL_USER=lportal
MYSQL_PASS=lportal
MYSQL_DBNM=lportal
MYSQL_ROOT=root
MYSQL_RPAS=

# This file contains common variables for setup_* scripts it may be used to override above settings
. setup_config.sh

# Install preliminary FutureGateway stuff
preinstall_fg() {
  if [ -f $FGENV ]; then
    echo "WARNING: Setup file registry already exists, you are executing again the setup script"
    printf "Are you sure you want to execute setup again (y/N)? "
    read ANSWER
    if [ "${ANSWER}" != "y" ]; then
      echo "Aborted"
      return 1
    fi 
  fi
  echo "Setup script for the FutureGateway portal"
  echo "-----------------------------------------"
  echo "The system will be installed in: $FGLOCATION"
  if [ $LIFERAY_SDK_ON -ne 0 ]; then
    echo "Liferay SDK will be isntalled"
    echo "The SDK location will be in: $LIFERAY_SDK_LOCATION"
  else
    echo "Liferay SDK will be not isntalled"
  fi
  SYSTEM=$(uname -s)
  JVER=$(java -version 2>&1 | awk -F'"' '{ print $2 }' | awk -F"_" '{ print $1 }' | sed s/'\.'//g)
  if [ "${JVER}" = "" ]; then
    JVER=0
  fi
  if [ $JVER -lt 160 ]; then
    echo "FATAL: Please install java >= 1.6.0 first"
    return 1
  fi
  # MySQL database
  if [ $SETUPDB -ne 0 ]; then
    cat > /tmp/lportal_create.sql <<EOF
-- FutureGateway: lportal database creation script
-- !!! PAY ATTENTION existing lportal databse on the !!!
-- !!! specified target will be dropped.             !!!
drop database if exists ${MYSQL_DBNM};
create database ${MYSQL_DBNM} character set utf8;
grant all privileges on ${MYSQL_USER}.* to '${MYSQL_DBNM}'@'localhost' identified by '${MYSQL_PASS}';
grant all privileges on ${MYSQL_USER}.* to '${MYSQL_DBNM}'@'%' identified by '${MYSQL_PASS}';
EOF
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
    $MYSQL -u${MYSQL_ROOT} $PASSOPT < /tmp/lportal_create.sql
    RES=$?
    rm -f /tmp/lportal_create.sql
    if [ $RES -ne 0 ]; then
      echo "FATAL: Something went wrong creating liferay database"
      return 1
    fi
  fi
  # Test connection
  MYSQL=$(which mysql)
  if [ "${MYSQL}" = "" ]; then
    echo "WARNING: The mysql client is missing; unable to test connection"
  else
    cat > /tmp/lportal_conntest.sql <<EOF
-- FutureGateway: lportal connection test
show tables;
EOF
    $MYSQL -u${MYSQL_USER} -p${MYSQL_PASS} ${MYSQL_DBNM} < /tmp/lportal_conntest.sql
    RES=$?
    rm -f /tmp/lportal_conntest.sql
    if [ $RES -ne 0 ]; then
      echo "FATAL: Unable to connect liferay database"
      return 1
    else
      echo "Successfully connected to liferay database"
    fi
  fi
  # File repository
  if [ "${FGREPO}" = "" ]; then
    echo "FATAL: File repository not specified; please configure a path for it"
    return 1
  fi
  if [ ! -d $FGREPO ]; then
    echo "Not existing file repository; creating it at: $FGREPO"    
    # Encoded FGRepo
    if [ -f FGRepo.tar.gz ]; then
      echo "Found the repository archive package; installing it"
      tar xvfz FGRepo.tar.gz
      # Archive could be named differently by the user
      [ "${FGREPO}" != "FGRepo" ] || mv FGRepo $(dirname $FGREPO)/$(basename $FGREPO)
    else
      echo "Creating file repository directory at: $FGREPO"
      mkdir -p $FGREPO
    fi
  else
    NUMREPOFILES=$(ls -1 $FGREPO | wc -l)
    printf "File repository exists at: $FGREPO containing %3d files.\n" $NUMREPOFILES
    if [ $NUMREPOFILES -ne 0 ]; then
      echo "Cache content:"
      ls -1 $FGREPO
    else
      echo "Cache is empty; it will be filled during the installation"
    fi
  fi
  # Prepare destination dir and store setup running
  # directory (RUNDIR) for future reference to .fgSetup
  RUNDIR=$(pwd)
  mkdir -p $FGLOCATION
  # From now on the each installation phase assumes that the 
  # current directory is $FGLOCATION; during the installation
  # the current directory could be changed but always included
  # into a: cd .../newpath; cd - block statements
  # RUNDIR will contain the directory path at the setup execution
  # time
  cd $FGLOCATION
  # Environment variables file
  if [ ! -e $FGENV ]; then
    cat > $FGENV <<EOF
#!/bin/bash
#
# This is the FutureGateway environment variable file
#
export RUNDIR=${RUNDIR}
export FGSETUP=${RUNDIR}/.fgSetup
export FGLOCATION=${FGLOCATION}
EOF
    chmod +x $FGENV
  fi
  echo "Installing FutureGateway ..."
  get_ts
  echo "$TS preinstall" >> $RUNDIR/.fgSetup
  return 0
}

# Download and install Tomcat 8
install_tomcat8() {
  if [ -e $RUNDIR/.fgSetup ]; then
    SETUPCHK=$(cat $RUNDIR/.fgSetup | grep "tomcat")
  else
    SETUPCHK=""
  fi
  if [ "${SETUPCHK}" != "" ]; then
    echo "Apache tomcat seems to be already installed; skipping this phase"
    if [ "${SYSTEM}" = "Darwin" ]; then # MacOSX
      export CATALINA_HOME=$FGLOCATION/apache-tomcat-8.0.26
      export JAVA_HOME=$(/usr/libexec/java_home)
    elif [ "${SYSTEM}" = "Linux" ]; then
      export CATALINA_HOME=$FGLOCATION/apache-tomcat-8.0.26
      export JAVA_HOME=$(readlink -f $(which java) | sed s/"\/bin\/java"//)
    else
      echo "FATAL: Unsupported system (${SYSTEM}), environment variables not set"
      echo "       please configure by your own the follwing environment variables"
      echo "       into the setup file:"
      echo "       CATALINA_HOME=${CATALINA_HOME}"
      echo "       JAVA_HOME=${JAVA_HOME}"
      return 1
    fi
    return 0
  fi
  echo "Installing Apache Tomcat 8.0.26"
  get_file http://it.apache.contactlab.it/tomcat/tomcat-8/v8.0.26/bin/apache-tomcat-8.0.26.zip
  unzip apache-tomcat-8.0.26.zip 
  rm -f apache-tomcat-8.0.26.zip
  chmod +x $FGLOCATION/apache-tomcat-8.0.26/bin/*.sh
  # Set the environment
  echo "${SYSTEM} system detected; updating setenv.sh file accordingly"
  if [ "${SYSTEM}" = "Darwin" ]; then # MacOSX
    echo "" >> $FGENV 
    echo "export CATALINA_HOME=${FGLOCATION}/apache-tomcat-8.0.26" >> $FGENV 
    echo "export JAVA_HOME=\$(/usr/libexec/java_home)" >> $FGENV 
    export CATALINA_HOME=$FGLOCATION/apache-tomcat-8.0.26
    export JAVA_HOME=$(/usr/libexec/java_home)
  elif [ "${SYSTEM}" = "Linux" ]; then
    echo "" >> $FGENV 
    echo "export CATALINA_HOME=${FGLOCATION}/apache-tomcat-8.0.26" >> $FGENV 
    echo "export JAVA_HOME=\$(readlink -f $(which java) | sed s/\"\/bin\/java\"//)" >> $FGENV 
    export CATALINA_HOME=$FGLOCATION/apache-tomcat-8.0.26
    export JAVA_HOME=$(readlink -f $(which java) | sed s/"\/bin\/java"//)
  else
    echo "WARNING: Unsupported system (${SYSTEM}), environment variables not set"
    echo "         please configure by your own the follwing environment variables"
    echo "         into your system startup file:"
    echo "         CATALINA_HOME=${CATALINA_HOME}"
    echo "         JAVA_HOME=${JAVA_HOME}"
  fi
  # Tomcat users
  NROWS=$(cat $CATALINA_HOME/conf/tomcat-users.xml | wc -l)
  mv $CATALINA_HOME/conf/tomcat-users.xml $CATALINA_HOME/conf/tomcat-users.xml_orig
  cat $CATALINA_HOME/conf/tomcat-users.xml_orig | head -n $((NROWS-1)) > $CATALINA_HOME/conf/tomcat-users.xml
  echo "" >> $CATALINA_HOME/conf/tomcat-users.xml
  cat >> $CATALINA_HOME/conf/tomcat-users.xml <<EOF
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="tomcat"/>
  <role rolename="liferay"/>
  <user username="${TOMCATUSR}" password="${TOMCATPAS}" roles="tomcat,liferay,manager-gui,manager-script"/>
</tomcat-users>
EOF
  # report to .fgSetup to track success
  get_ts
  echo "$TS   tomcat" >> $RUNDIR/.fgSetup
  return 0
}

# liferay isntallation step (tomcat configuration)
install_liferay_conftomcat() {
  if [ -e $RUNDIR/.fgSetup ]; then
    SETUPCHK=$(cat $RUNDIR/.fgSetup | grep "lfry_tconf")
  else
    SETUPCHK=""
  fi
  if [ "${SETUPCHK}" != "" ]; then
    echo "Liferay tomcat configuration seems to be already installed; skipping this phase"
    return 0
  fi  
  # Tomcat configuration
  cat > $CATALINA_HOME/bin/setenv.sh <<EOF
CATALINA_OPTS="\$CATALINA_OPTS -Dfile.encoding=UTF8 -Dorg.apache.catalina.loader.WebappClassLoader.ENABLE_CLEAR_REFERENCES=false -Duser.timezone=${TIMEZONE} -Xmx1024m -XX:MaxPermSize=256m"
EOF
  chmod +x $CATALINA_HOME/bin/setenv.sh
  mkdir -p $CATALINA_HOME/conf/Catalina/localhost
  cat > $CATALINA_HOME/conf/Catalina/localhost/ROOT.xml <<EOF
<Context path="" crossContext="true">

    <!-- JAAS -->

    <!--<Realm
        classNjame="org.apache.catalina.realm.JAASRealm"
        appName="PortalRealm"
        userClassNames="com.liferay.portal.kernel.security.jaas.PortalPrincipal"
        roleClassNames="com.liferay.portal.kernel.security.jaas.PortalRole"
    />-->

    <!--
    Uncomment the following to disable persistent sessions across reboots.
    -->

    <!--<Manager pathname="" />-->

    <!--
    Uncomment the following to not use sessions. See the property
    "session.disabled" in portal.properties.
    -->

    <!--<Manager className="com.liferay.support.tomcat.session.SessionLessManagerBase" />-->

    <!-- Disabled; configured global scope resources in server.xml
    <Resource
        name="jdbc/LiferayPool"
        auth="Container"
        type="javax.sql.DataSource"
        driverClassName="com.mysql.jdbc.Driver"
        url="jdbc:mysql://${MYSQL_HOST}/${MYSQL_DBNM}?useUnicode=true&amp;characterEncoding=UTF-8"
        username="${MYSQL_USER}"
        password="${MYSQL_PASS}"
        maxActive="100"
        maxIdle="30"
        maxWait="10000"
    />
    -->
    
    <Resource
        name="mail/MailSession"
        auth="Container"
        type="javax.mail.Session"
        mail.pop3.host="pop.gmail.com"
        mail.pop3.port="110"
        mail.smtp.host="smtp.gmail.com"
        mail.smtp.port="465"
        mail.smtp.user="user"
        mail.smtp.password="password"
        mail.smtp.auth="true"
        mail.smtp.starttls.enable="true"
        mail.smtp.socketFactory.class="javax.net.ssl.SSLSocketFactory"
        mail.imap.host="imap.gmail.com"
        mail.imap.port="993"
        mail.transport.protocol="smtp"
        mail.store.protocol="imap"
    />
</Context>
EOF
  # Avoid waring issue inside logs
  cp $CATALINA_HOME/conf/context.xml $CATALINA_HOME/conf/context.xml_orig
  NUMLINES=$(cat $CATALINA_HOME/conf/context.xml_orig | wc -l)
  cat $CATALINA_HOME/conf/context.xml_orig | head -n $((NUMLINES-1)) > $CATALINA_HOME/conf/context.xml
  cat >> $CATALINA_HOME/conf/context.xml <<EOF
<Resources
   cachingAllowed="true"
   cacheMaxSize="100000"
/>
</Context>
EOF
  rm -f $CATALINA_HOME/conf/context.xml_orig
  # Adjust catalina.properties
  cd $CATALINA_HOME/conf
  mv catalina.properties catalina.properties_orig
  CATPROPLN=$(cat catalina.properties_orig | grep -n common.loader | awk -F':' '{ print $1}')
  cat catalina.properties_orig | head -n $((CATPROPLN-1)) > catalina.properties
  echo "common.loader=\"\${catalina.base}/lib\",\"\${catalina.base}/lib/*.jar\",\"\${catalina.home}/lib\",\"\${catalina.home}/lib/*.jar\",\"\${catalina.home}/lib/ext\",\"\${catalina.home}/lib/ext/*.jar\"" >> catalina.properties
  CATPROPSZ=$(cat catalina.properties_orig | wc -l)
  cat catalina.properties_orig | tail -n $((CATPROPSZ-CATPROPLN)) >> catalina.properties
  rm -f catalina.properties_orig
  
  # Configuring global-scope GridEngine jdbc resources
  cp $CATALINA_HOME/conf/server.xml $CATALINA_HOME/conf/server.xml_orig  
  GNRENDLINE=$(cat $CATALINA_HOME/conf/server.xml | grep -n "</GlobalNamingResources>" | awk -F":" '{ print $1 }')
  cat $CATALINA_HOME/conf/server.xml_orig | head -n $((GNRENDLINE-1)) > $CATALINA_HOME/conf/server.xml
  cat >> $CATALINA_HOME/conf/server.xml <<EOF
    <Resource name="jdbc/UserTrackingPool"
              auth="Container"
              type="javax.sql.DataSource"
              username="tracking_user"
              password="usertracking"
              driverClassName="com.mysql.jdbc.Driver"
              description="UsersTrackingDB connection"
              url="jdbc:mysql://localhost:3306/userstracking"
              maxActive="100"
              maxIdle="30"
              maxWaitMillis="10000"/>

    <Resource name="jdbc/gehibernatepool"
              auth="Container"
              type="javax.sql.DataSource"
              username="tracking_user"
              password="usertracking"
              driverClassName="com.mysql.jdbc.Driver"
              description="UsersTrackingDB connection"
              url="jdbc:mysql://localhost:3306/userstracking"
              maxActive="100"
              maxIdle="30"
              maxWaitMillis="10000"/>
EOF
  cat $CATALINA_HOME/conf/server.xml_orig | tail -n +$GNRENDLINE >> $CATALINA_HOME/conf/server.xml
  rm -f $CATALINA_HOME/conf/server.xml_orig
  cd -
  # report to .fgSetup to track success
  get_ts
  echo "$TS     lfry_tconf" >> $RUNDIR/.fgSetup
}

# liferay isntallation step (liferay dependencies for tomcat)
install_liferay_dependencies() {
  if [ -e $RUNDIR/.fgSetup ]; then
    SETUPCHK=$(cat $RUNDIR/.fgSetup | grep "lfry_deps")
  else
    SETUPCHK=""
  fi
  if [ "${SETUPCHK}" != "" ]; then
    echo "Liferay dependencies seem to be already installed; skipping this phase"
    return 0
  fi
  # Liferay dependencies
  mkdir -p $CATALINA_HOME/lib/ext
  get_file http://sourceforge.net/projects/lportal/files/Liferay%20Portal/6.2.3%20GA4/liferay-portal-dependencies-6.2-ce-ga4-20150416163831865.zip/download "" liferay-portal-dependencies-6.2-ce-ga4-20150416163831865.zip
  unzip liferay-portal-dependencies-6.2-ce-ga4-20150416163831865.zip
  cd liferay-portal-dependencies-6.2-ce-ga4
  cp *.jar $CATALINA_HOME/lib/ext/
  cd -
  rm -rf  liferay-portal-dependencies-6.2-ce-ga4 liferay-portal-dependencies-6.2-ce-ga4-20150416163831865.zip
  get_file http://search.maven.org/remotecontent?filepath=com/liferay/portal/support-tomcat/6.2.1/support-tomcat-6.2.1.jar $CATALINA_HOME/lib/ext 
  # Now get other jars from source distribution
  get_file "http://downloads.sourceforge.net/project/lportal/Liferay%20Portal/6.2.3%20GA4/liferay-portal-src-6.2-ce-ga4-20150416163831865.zip?r=http%3A%2F%2Fwww.liferay.com%2Fdownloads%2Fliferay-portal%2Favailable-releases&ts=1442310167&use_mirror=vorboss" "" liferay-portal-src-6.2-ce-ga4-20150416163831865.zip
  unzip liferay-portal-src-6.2-ce-ga4-20150416163831865.zip
  cd liferay-portal-src-6.2-ce-ga4
  cp ./lib/development/activation.jar $CATALINA_HOME/lib/ext/
  cp ./lib/development/jms.jar  $CATALINA_HOME/lib/ext/
  cp ./lib/development/jta.jar $CATALINA_HOME/lib/ext/
  cp ./lib/development/jutf7.jar $CATALINA_HOME/lib/ext/
  cp ./lib/development/mail.jar $CATALINA_HOME/lib/ext/
  cp ./lib/development/persistence.jar $CATALINA_HOME/lib/ext/
  cp ./lib/portal/ccpp.jar $CATALINA_HOME/lib/ext/
  cd -
  rm -rf liferay-portal-src-6.2-ce-ga4
  rm -rf liferay-portal-src-6.2-ce-ga4-20150416163831865.zip
  get_file http://central.maven.org/maven2/mysql/mysql-connector-java/5.1.21/mysql-connector-java-5.1.21.jar $CATALINA_HOME/lib/ext
  # report to .fgSetup to track success
  get_ts
  echo "$TS     lfry_deps" >> $RUNDIR/.fgSetup
}

# liferay_sdk isntallation step (apache.ant)
install_liferay_sdk_ant() {
  if [ -e $RUNDIR/.fgSetup ]; then
    SETUPCHK=$(cat $RUNDIR/.fgSetup | grep "apacheant")
  else
    SETUPCHK=""
  fi
  if [ "${SETUPCHK}" != "" ]; then
    echo "Apache ANT seems to be already installed; skipping this phase"
    export ANT_HOME=${FGLOCATION}/apache-ant-1.9.6
    export PATH=${PATH}:${ANT_HOME}/bin
    return 0
  fi
  echo "Installing ANT (pre-requisite)"
  get_file http://it.apache.contactlab.it//ant/binaries/apache-ant-1.9.6-bin.zip
  unzip apache-ant-1.9.6-bin.zip
  rm -f apache-ant-1.9.6-bin.zip
  echo "export ANT_HOME=${FGLOCATION}/apache-ant-1.9.6" >> $FGENV 
  echo "export PATH=\$PATH:\${ANT_HOME}/bin" >> $FGENV 
  export ANT_HOME=${FGLOCATION}/apache-ant-1.9.6
  export PATH=$PATH:${ANT_HOME}/bin
  # report to .fgSetup to track success  
  get_ts
  echo "$TS       apacheant" >> $RUNDIR/.fgSetup
}

install_liferay_sdk_maven() {
  if [ -e $RUNDIR/.fgSetup ]; then
    SETUPCHK=$(cat $RUNDIR/.fgSetup | grep "apachemaven")
  else
    SETUPCHK=""
  fi
  if [ "${SETUPCHK}" != "" ]; then
    echo "Maven seems to be already installed; skipping this phase"
    export PATH=$PATH:$FGLOCATION/apache-maven-3.3.3
    return 0
  fi
  if [ $MAVEN_ON -eq 0 ]; then
    echo "Skipping LIFERAY SDK"
    return 0
  fi
  get_file http://apache.panu.it/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.zip
  unzip apache-maven-3.3.3-bin.zip
  rm -f apache-maven-3.3.3-bin.zip
  echo "export PATH=\$PATH:$FGLOCATION/apache-maven-3.3.3/bin" >> $FGENV 
  export PATH=$PATH:$FGLOCATION/apache-maven-3.3.3
  # report to .fgSetup to track success    
  get_ts
  echo "$TS       apachemaven" >> $RUNDIR/.fgSetup
}

# installl liferay_sdk
install_liferay_sdk() {
  if [ -e $RUNDIR/.fgSetup ]; then
    SETUPCHK=$(cat $RUNDIR/.fgSetup | grep "lfry_sdk")
  else
    SETUPCHK=""
  fi
  if [ "${SETUPCHK}" != "" ]; then
    echo "Liferay SDK seems to be already installed; skipping this phase"
    return 0
  fi
  if [ $LIFERAY_SDK_ON -eq 0 ]; then
    echo "Skipping LIFERAY SDK"
    return 0
  fi
  
  echo "Installing Liferay SDK v6.2"
  install_liferay_sdk_ant
  echo "Installing LIFERAY SDK"
  get_file http://sourceforge.net/projects/lportal/files/Liferay%20Portal/6.2.3%20GA4/liferay-plugins-sdk-6.2-ce-ga4-20150416163831865.zip/download $FGLOCATION liferay-plugins-sdk-6.2-ce-ga4-20150416163831865.zip
  unzip $FGLOCATION/liferay-plugins-sdk-6.2-ce-ga4-20150416163831865.zip -d $LIFERAY_SDK_LOCATION
  rm -f liferay-plugins-sdk-6.2-ce-ga4-20150416163831865.zip 
  cd $LIFERAY_SDK_LOCATION/liferay-plugins-sdk-6.2
  mv build.properties build.properties_orig
  cat build.properties_orig | sed s/"tomcat-7\.0\.42"/"apache-tomcat-8\.0\.26"/ > build.properties_1
  cat build.properties_1 | sed s/"\${sdk\.dir}\/\.\.\/bundles"/"\${sdk\.dir}\/\.\.\/"/ > build.properties
  rm -f build.properties_1
  rm -f build.properties_orig
  # Future changes may be placed for    
  #app.server.tomcat.manager.user=tomcat
  #app.server.tomcat.manager.password=tomcat
  mkdir -p $CATALINA_HOME/webapps/ROOT/WEB-INF/lib
  chmod +x $LIFERAY_SDK_LOCATION/liferay-plugins-sdk-6.2/portlets/create.sh
  cd $LIFERAY_SDK_LOCATION/liferay-plugins-sdk-6.2/portlets
  ./create.sh "fginstallation" "FutureGatewayTest"
  cd -
  cd  $LIFERAY_SDK_LOCATION/liferay-plugins-sdk-6.2/portlets/fginstallation-portlet
  ant compile # This will install ECJ automatically
  ant compile # This because asked to re-compile
  cd -
  cd $LIFERAY_SDK_LOCATION/liferay-plugins-sdk-6.2/portlets
  rm -rf fginstallation # Remove fginstallation portlet
  cd -
  
  # maven
  echo "Installing Maven"
  install_liferay_sdk_maven

  # report to .fgSetup to track success    
  get_ts
  echo "$TS     lfry_sdk" >> $RUNDIR/.fgSetup
}

# Download and isntall Liferay community ed. 6.2.3 and its SDK (if requested)
install_liferay() {
  if [ -e $RUNDIR/.fgSetup ]; then
    SETUPCHK=$(cat $RUNDIR/.fgSetup | grep "liferay")
  else
    SETUPCHK=""
  fi
  if [ "${SETUPCHK}" != "" ]; then
    echo "Liferay seems to be already installed; skipping this phase"
    return 0
  fi
  # The present installation refers to the instructions available at:
  # https://dev.liferay.com/discover/deployment/-/knowledge_base/6-2/installing-liferay-on-tomcat-7
  echo "Installing Liferay community ed. v6.2"
  if [ ! -d $CATALINA_HOME/webapps ]; then
    echo "FATAL: No webapps destination folder found"
    return 1
  fi
  # Pre-installation steps
  install_liferay_dependencies
  install_liferay_conftomcat
  # Install Liferay
  get_file http://sourceforge.net/projects/lportal/files/Liferay%20Portal/6.2.3%20GA4/liferay-portal-6.2-ce-ga4-20150416163831865.war/download $CATALINA_HOME/webapps liferay-portal-6.2-ce-ga4-20150416163831865.war
  if [ -d $CATALINA_HOME/webapps/ROOT ]; then
    echo "Tomcat webabbps/ROOT dir already exists; saving its content before removing it"
    tar cvfz ROOT_orig.tar.gz  $CATALINA_HOME/webapps/ROOT
    rm -rf $CATALINA_HOME/webapps/ROOT
  fi
  unzip $CATALINA_HOME/webapps/liferay-portal-6.2-ce-ga4-20150416163831865.war -d $CATALINA_HOME/webapps/ROOT
  rm -f $CATALINA_HOME/webapps/liferay-portal-6.2-ce-ga4-20150416163831865.war
  # Setup portal-ext.properties
  # portal-ext.properties location depends from liferay.home value that 
  # currently is located at $FGLOCATION. As a consequence of this, also
  # the 'deploy' directory will be placed on that directory.
  echo "jdbc.default.jndi.name=jdbc/LiferayPool"  > $FGLOCATION/portal-ext.properties
  echo "mail.session.jndi.name=mail/MailSession" >> $FGLOCATION/portal-ext.properties
  # Optionally install liferay SDK
  install_liferay_sdk
  # report to .fgSetup to track success
  get_ts
  echo "$TS   liferay" >> $RUNDIR/.fgSetup
  return 0
}

# Installation closure for FutureGateway stuff
postinstall_fg() {
  cd $RUNDIR
  # Killjava util
  # After calling $CATALINA_HOME/bin/shutdown a java
  # process still persists even killing its process
  # the following function take care of this
  cat >> $FGENV <<EOF
killjava() {
    if [ "\${1}" = "-f" ]; then
      KILLARG="-9"
    fi
    PROC=\$(ps -ef | grep java | grep tomcat | grep -v grep | awk '{ print \$2}') 
    while [ "\${PROC}" != "" ]; do  
        kill \$KILLARG \$PROC;         
        sleep 1
        PROC=\$(ps -ef | grep java | grep tomcat | grep -v grep | awk '{ print \$2}')
    done
}
start_tomcat() {
    ARG=\$1
    if [ $((ARG*ARG)) -ne 0 ]; then
        RESTOFCOMMANDARG=" && tail -f \$CATALINA_HOME/logs/catalina.out"
    else
        RESTOFCOMMANDARG=""
    fi
    if [ "\${CATALINA_HOME}" != "" ]; then
        \$CATALINA_HOME/bin/startup.sh \$RESTOFCOMMANDARG
    else
        echo "ERROR: CATALINA_HOME environment variable not set"
    fi
}
stop_tomcat() {
    ARG=\$1
    if [ \$((ARG*ARG)) -ne 0 ]; then
        RESTOFCOMMANDARG=" && killjava()"
    else
        RESTOFCOMMANDARG=""
    fi
    if [ "\${CATALINA_HOME}" != "" ]; then
        \$CATALINA_HOME/bin/shutdown.sh \$RESTOFCOMMANDARG
    else
        echo "ERROR: CATALINA_HOME environment variable not set"
    fi
}
EOF
  # Udpade bash_profile
  FGENV_PROFILE=$(cat $HOME/.bash_profile | grep "FutureGateway")
  if [ "${FGENV_PROFILE}" = "" ]; then
    cat >> $HOME/.bash_profile <<EOF
# FutureGateway environment settings (! do not remove this line)
. ${FGENV}
EOF
  fi
  # DEB needs a further entry in profile since .bash_profile overrides .profile
  if [ "${APTGET}" != "" ]; then
    echo ". .profile" >> $HOME/.bash_profile
  fi 
  
  # Final message
  echo "Script installation accomplished"
  echo "You can start now tomcath with: \$CATALINA_HOME/bin/startup.sh"
  echo "WARNING: Please execute tomcat from another terminal since new enviornment"
  echo "         environment settings are now available, or you may source first"
  echo "         the configuration file: ${FGENV}"
  echo "         You can watch anytime tomcat server activity with:"
  echo "         tail -f \$CATALINA_HOME/logs/catalina.out"
  echo ""
  # report to .fgSetup to track success  
  get_ts
  echo "$TS fgend" >> $RUNDIR/.fgSetup
  return 0
}

# Remove all FutureGateway components
fg_uninstall() {
  # Check FGSETUP
  #if [ "${FGSETUP}" = "" ]; then
  #  echo "FATAL: FGSETUP environment variable is empty; please check FutureGateway environment variables file"
  #  return 1
  #fi
  #if [ ! -f $FGSETUP ]; then
  #  echo "FATAL: Unable to locate installation file referenced by \$FGSETUP inside the FutureGateway environment variables file"
  #  return 1
  #fi
  # Check FGLOCATION
  #if [ "${FGLOCATION}" = "" ]; then
  #  echo "FATAL: FGLOCATION environment variable is empty; please check FutureGateway environment variables file"
  #  return 1
  #fi
  #if [ ! -d $FGLOCATION ]; then
  #  echo "FATAL: Unable to locate installation directory referenced by \$FGLOCATION inside the FutureGateway environment variables file"
  #  return 1
  #fi
  printf "Removing $FGLOCATION ..."
  rm -rf $FGLOCATION >/dev/null 2>/dev/null
  if [ $? -ne 0 ]; then echo " failed"; else echo " ok"; fi
  printf "Removing environment ..."
  FGLINE=$(cat $HOME/.bash_profile | grep  -n "FutureGateway environment settings" | awk -F':' '{ print $1 }')
  if [ "${FGLINE}" != "" ]; then
    BPLINES=$(cat $HOME/.bash_profile | wc -l)
    cp $HOME/.bash_profile $HOME/.bash_profile_orig
    cat $HOME/.bash_profile_orig | head -n $((FGLINE-1)) > $HOME/.bash_profile
    cat $HOME/.bash_profile_orig | tail -n $((BPLINES-FGLINE-1)) >> $HOME/.bash_profile
    rm -f $HOME/.bash_profile_orig
    echo " ok"
  else
    echo " warn (FutureGateway env setting not found)"
  fi
  printf "Removing setup control file ..."
  rm -f $FGSETUP
  echo " ok"
}

##
## Script execution
##
if [ "${1}" != "" ]; then
  if [ "${1}" = "-u" ]; then
    echo "Uninstalling FutureGateway ..."
    fg_uninstall
  elif [ "${1}" = "-h" -o "${1}" = "--help" ]; then
    SNAME=$(basename $0)
    echo "Usage: ${SNAME} [-u] [-h|--help]"
    echo "Execute without arguments to install FutureGateway"
    echo "Use -h or --help to show this page"
    echo ""
    echo "This script will install apache.tomcat8+Liferay6.2 and"
    echo "optionally liferay_sdk"
    echo "Before to proceed with the installation; be sure your"
    echo "system has installed Java(tm) v>=1.6.0, you also have"
    echo "a mysql database to target as 'root' and preferably"
    echo "a mysql client application used by this script to test"
    echo "the DB connection."
    echo "Please also check any environment variable specified"
    echo "on top of this script in order to locate correctly"
    echo "any component on your system."
    echo ""
    exit 0
  else
    echo "FATAL: Unrecognized option: \"${1}\""
    exit 1
  fi
else
  echo "Installing FutureGateway ..."
  # Perform installation
  preinstall_fg &&       \
  install_tomcat8 &&     \
  install_liferay &&     \
  postinstall_fg
fi
exit 0
