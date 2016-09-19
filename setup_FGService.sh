#!/bin/bash
#
# Setup script for the FutureGateway portal, installing init.d/futuregateway script
#
# 11.03.2016 - riccardo.bruno@ct.infn.it
#

# Load common setting and setup functions
. setup_config.sh common
. setup_config.sh functions

#
# This script provides the init script to execute FutureGateway service at startup
#

# 1st ensure that this script executes as su/root priviledges
if [ $(id -u) != 0 ]; then
  echo "Please execute this script with sudo or as a root user"
  exit 1
fi

BREW=$(which brew >/dev/null 2>/dev/null)
APTGET=$(which apt-get 2>/dev/null)
YUM=$(which yum 2>/dev/null)

if [ "$BREW" != "" ]; then
  echo "Service control script is not supported yet for Mac OS X platfomr"
  exit 1
fi

if [ "$YUM" != "" ]; then
  RHREL=$(cat /etc/redhat-release | sed 's/[^0-9.]*//g' | awk -F"." '{ print $1 }')
  USESYSCTL=0
  [ $((RHREL-6)) > 0 ] && USESYSCTL=1
fi

if [ $USESYSCTL -eq 0 ]; then
  echo "Installating Futuregateway service control script in /etc/init.d"
  cat >/etc/init.d/futuregateway << EOF
#! /bin/sh
### BEGIN INIT INFO
# Provides: futuregateway
# Required-Start: \$remote_fs \$syslog
# Required-Stop: \$remote_fs \$syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: FutureGateway
# Description: This file starts and stops FutureGateway portal and/or its API Server
#
### END INIT INFO

ENABLEFRONTEND=1 # In production environment this flag should be placed to 0
FRONTENDSESSIONNAME=fgAPIServer
SCREEN=\$(which screen)
FGUSER=futuregateway
TOMCAT_DIR=\$(su - \$FGUSER -c "echo \\\$CATALINA_HOME")
export JAVA_HOME=\$(su - \$FGUSER -c "echo \\\$JAVA_HOME")

futuregateway_proc() {
  JAVAPROC=\$(ps -ef | grep java | grep tomcat | grep -v grep | grep -v ps | awk '{ print \$2}')
  echo \$JAVAPROC
}

frontend_session() {
  SESSION=\$(su - \$FGUSER -c "screen -ls | grep \$FRONTENDSESSIONNAME")
  echo \$SESSION | awk '{ print \$1 }' | xargs echo
}

fgAPIServer_start() {
  if [ "\$SCREEN" = "" ]; then
    echo "Unable to start fgAPIServer without screen command"
    return 1
  fi
  FRONTENDSESSION=\$(frontend_session)
  if [ "\$FRONTENDSESSION" != "" ]; then
    echo "APIServer front-end screen session already exists"
  else
    FGPROC=\$(ps -ef | grep python | grep fgapiserver.py | head -n 1)
    if [ "\$FGPROC" != "" ]; then
      echo "APIServer front-end is already running"
    else
      su - \$FGUSER -c "screen -dmS \$FRONTENDSESSIONNAME bash"
      FRONTENDSESSION=\$(frontend_session)
      su - \$FGUSER -c "screen -S \$FRONTENDSESSIONNAME -X stuff \"cd \\\\\\\$FGLOCATION/fgAPIServer\\n\""
      su - \$FGUSER -c "screen -S \$FRONTENDSESSIONNAME -X stuff \"./fgapiserver.py\\n\""
    fi
  fi
}

fgAPIServer_stop() {
  if [ "\$SCREEN" = "" ]; then
    echo "Unable to stop fgAPIServer without screen command"
    return 1
  fi
  FRONTENDSESSION=\$(frontend_session)
  if [ "\$FRONTENDSESSION" = "" ]; then
    echo "APIServer front-end already stopped"
  else
    su - \$FGUSER -c "screen -X -S \$FRONTENDSESSIONNAME quit"
  fi
}

futuregateway_start() {
  JAVAPROC=\$(futuregateway_proc)
  if [ "\$JAVAPROC" != "" ]; then
    echo "FutureGateway already running"
  else
    su - \$FGUSER -c start_tomcat
  fi
  if [ \$ENABLEFRONTEND -ne 0 ]; then
    fgAPIServer_start
  else
    echo "fgAPIServer front-end disabled"
  fi
}

futuregateway_stop() {
  JAVAPROC=\$(futuregateway_proc)
  if [ "\$JAVAPROC" != "" ]; then
    su - \$FGUSER -c stop_tomcat
    sleep 10
    JAVAPROC=\$(futuregateway_proc)
    if [ "\$JAVAPROC" != "" ]; then
      printf "Java process still active; killing ... "
      while [ "\$JAVAPROC" != "" ]; do
        kill \$JAVAPROC;
        JAVAPROC=\$(futuregateway_proc)
      done
      echo "done"
    fi
  else
    echo "FurureGateway already stopped"
  fi
  if [ \$ENABLEFRONTEND -ne 0 ]; then
    fgAPIServer_stop
  else
    echo "fgAPIServer front-end disabled"
  fi
}

futuregateway_status() {
  if [ \$ENABLEFRONTEND -eq 0 ]; then
    echo "fgAPIServer front-end disabled"
  else
    JAVAPROC=\$(futuregateway_proc)
    if [ "\$JAVAPROC" != "" ]; then
      echo "Futuregateway is up and running"
    else
      echo "Futuregateway is stopped"
    fi
    FRONTENDSESSION=\$(frontend_session)
    if [ "\$FRONTENDSESSION" != "" ]; then
      echo "APIServer front-end is up and running"
    else
      echo "APIServer front-end is stopped"
    fi
  fi
}

case "\$1" in
 start)
   futuregateway_start
   ;;
 stop)
   futuregateway_stop
   ;;
 restart)
   futuregateway_stop
   sleep 20
   futuregateway_start
   ;;
 status)
   futuregateway_status
   ;;
 *)
   echo "Usage: futuregateway {start|stop|restart|status}" >&2
   exit 3
   ;;
esac
EOF
  chmod a+x /etc/init.d/futuregateway
  if [ "$APTGET" != "" ]; then
    update-rc.d futuregateway defaults
    #
    # Ubuntu 14.04 bug, screen section does not start at boot
    #
    OSREL=$(lsb_release -r | awk '{ print $2}')
    if [ "$OSREL" = "14.04" ]; then
      # To workaround this, place the futuregateway service execution inside rc.local
      replace_line "/etc/rc.local" "exit 0" "/etc/init.d/futuregateway start\nexit 0" "orig"
    fi
  else
    chkconfig futuregateway on
  fi
else
  echo "Installating Futuregateway service control script using systemctl"
  cat >futuregateway.bin << EOF
#! /bin/sh
ENABLEFRONTEND=1 # In production environment this flag should be placed to 0
FRONTENDSESSIONNAME=fgAPIServer
SCREEN=\$(which screen)
FGUSER=futuregateway
TOMCAT_DIR=\$(su - \$FGUSER -c "echo \\\$CATALINA_HOME")
export JAVA_HOME=\$(su - \$FGUSER -c "echo \\\$JAVA_HOME")

futuregateway_proc() {
  JAVAPROC=\$(ps -ef | grep java | grep tomcat | grep -v grep | grep -v ps | awk '{ print \$2}')
  echo \$JAVAPROC
}

frontend_session() {
  SESSION=\$(su - \$FGUSER -c "screen -ls | grep \$FRONTENDSESSIONNAME")
  echo \$SESSION | awk '{ print \$1 }' | xargs echo
}

fgAPIServer_start() {
  if [ "\$SCREEN" = "" ]; then
    echo "Unable to start fgAPIServer without screen command"
    return 1
  fi
  FRONTENDSESSION=\$(frontend_session)
  if [ "\$FRONTENDSESSION" != "" ]; then
    echo "APIServer front-end screen session already exists"
  else
    FGPROC=\$(ps -ef | grep python | grep fgapiserver.py | head -n 1)
    if [ "\$FGPROC" != "" ]; then
      echo "APIServer front-end is already running"
    else
      su - \$FGUSER -c "screen -dmS \$FRONTENDSESSIONNAME bash"
      FRONTENDSESSION=\$(frontend_session)
      su - \$FGUSER -c "screen -S \$FRONTENDSESSIONNAME -X stuff \"cd \\\\\\\$FGLOCATION/fgAPIServer\\n\""
      su - \$FGUSER -c "screen -S \$FRONTENDSESSIONNAME -X stuff \"./fgapiserver.py\\n\""
    fi
  fi
}

fgAPIServer_stop() {
  if [ "\$SCREEN" = "" ]; then
    echo "Unable to stop fgAPIServer without screen command"
    return 1
  fi
  FRONTENDSESSION=\$(frontend_session)
  if [ "\$FRONTENDSESSION" = "" ]; then
    echo "APIServer front-end already stopped"
  else
    su - \$FGUSER -c "screen -X -S \$FRONTENDSESSIONNAME quit"
  fi
}

futuregateway_start() {
  JAVAPROC=\$(futuregateway_proc)
  if [ "\$JAVAPROC" != "" ]; then
    echo "FutureGateway already running"
  else
    su - \$FGUSER -c start_tomcat
  fi
  if [ \$ENABLEFRONTEND -ne 0 ]; then
    fgAPIServer_start
  else
    echo "fgAPIServer front-end disabled"
  fi
}

futuregateway_stop() {
  JAVAPROC=\$(futuregateway_proc)
  if [ "\$JAVAPROC" != "" ]; then
    su - \$FGUSER -c stop_tomcat
    sleep 10
    JAVAPROC=\$(futuregateway_proc)
    if [ "\$JAVAPROC" != "" ]; then
      printf "Java process still active; killing ... "
      while [ "\$JAVAPROC" != "" ]; do
        kill \$JAVAPROC;
        JAVAPROC=\$(futuregateway_proc)
      done
      echo "done"
    fi
  else
    echo "FurureGateway already stopped"
  fi
  if [ \$ENABLEFRONTEND -ne 0 ]; then
    fgAPIServer_stop
  else
    echo "fgAPIServer front-end disabled"
  fi
}

futuregateway_status() {
  if [ \$ENABLEFRONTEND -eq 0 ]; then
    echo "fgAPIServer front-end disabled"
  else
    JAVAPROC=\$(futuregateway_proc)
    if [ "\$JAVAPROC" != "" ]; then
      echo "Futuregateway is up and running"
    else
      echo "Futuregateway is stopped"
    fi
    FRONTENDSESSION=\$(frontend_session)
    if [ "\$FRONTENDSESSION" != "" ]; then
      echo "APIServer front-end is up and running"
    else
      echo "APIServer front-end is stopped"
    fi
  fi
}

case "\$1" in
 start)
   futuregateway_start
   ;;
 stop)
   futuregateway_stop
   ;;
 restart)
   futuregateway_stop
   sleep 20
   futuregateway_start
   ;;
 status)
   futuregateway_status
   ;;
 *)
   echo "Usage: futuregateway {start|stop|restart|status}" >&2
   exit 3
   ;;
esac
EOF
  su - -c 'cp futuregateway.bin /usr/local/bin/futuregateway && chmod +x /usr/local/bin/futuregateway'
  # systemctl service script
  cat futuregateway.service <<EOF
[Unit]
Description=Control the futuregateway service

[Service]
Type=oneshot
ExecStart=/bin/sh -c "/usr/local/bin/futuregateway start"
ExecStop=/bin/sh -c "/usr/local/bin/futuregateway stop"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
  su - -c 'cp futuregateway.service /etc/systemd/system/futuregateway && chmod +x /etc/systemd/system/futuregateway'
  rm -f futuregateway.bin futuregateway.service
  systemctl enable futuregateway.service
fi
#
# Following configuration script can be used to setup fgAPIServer frontend as
# a WSGI process. This is the recommended way when use the APIServer in a
# production environment
#
cat >fgAPIServer.conf <<EOF
<IfModule mod_ssl.c>
	<VirtualHost _default_:443>
		ServerName sgw.indigo-datacloud.eu
		ServerAdmin webmaster@localhost

		DocumentRoot /var/www/html

		# Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
		# error, crit, alert, emerg.
		# It is also possible to configure the loglevel for particular
		# modules, e.g.
		#LogLevel info ssl:warn

		ErrorLog \${APACHE_LOG_DIR}/error.log
		CustomLog \${APACHE_LOG_DIR}/access.log combined

		# For most configuration files from conf-available/, which are
		# enabled or disabled at a global level, it is possible to
		# include a line for only one particular virtual host. For example the
		# following line enables the CGI configuration for this host only
		# after it has been globally disabled with "a2disconf".
		#Include conf-available/serve-cgi-bin.conf

		#   SSL Engine Switch:
		#   Enable/Disable SSL for this virtual host.
		SSLEngine on

		#   A self-signed (snakeoil) certificate can be created by installing
		#   the ssl-cert package. See
		#   /usr/share/doc/apache2/README.Debian.gz for more info.
		#   If both key and certificate are stored in the same file, only the
		#   SSLCertificateFile directive is needed.
		SSLCertificateFile	/etc/ssl/certs/sgw_indigo-datacloud_eu.crt
		SSLCertificateKeyFile /etc/ssl/private/sgw_indigo-datacloud_eu.key

		#   Server Certificate Chain:
		#   Point SSLCertificateChainFile at a file containing the
		#   concatenation of PEM encoded CA certificates which form the
		#   certificate chain for the server certificate. Alternatively
		#   the referenced file can be the same as SSLCertificateFile
		#   when the CA certificates are directly appended to the server
		#   certificate for convinience.
		#SSLCertificateChainFile /etc/apache2/ssl.crt/server-ca
		SSLCertificateChainFile /etc/ssl/certs/DigiCertCA.crt

		#   Certificate Authority (CA):
		#   Set the CA certificate verification path where to find CA
		#   certificates for client authentication or alternatively one
		#   huge file containing all of them (file must be PEM encoded)
		#   Note: Inside SSLCACertificatePath you need hash symlinks
		#		 to point to the certificate files. Use the provided
		#		 Makefile to update the hash symlinks after changes.
		#SSLCACertificatePath /etc/ssl/certs/
		#SSLCACertificateFile /etc/apache2/ssl.crt/ca-bundle.crt

		#   Certificate Revocation Lists (CRL):
		#   Set the CA revocation path where to find CA CRLs for client
		#   authentication or alternatively one huge file containing all
		#   of them (file must be PEM encoded)
		#   Note: Inside SSLCARevocationPath you need hash symlinks
		#		 to point to the certificate files. Use the provided
		#		 Makefile to update the hash symlinks after changes.
		#SSLCARevocationPath /etc/apache2/ssl.crl/
		#SSLCARevocationFile /etc/apache2/ssl.crl/ca-bundle.crl

		#   Client Authentication (Type):
		#   Client certificate verification type and depth.  Types are
		#   none, optional, require and optional_no_ca.  Depth is a
		#   number which specifies how deeply to verify the certificate
		#   issuer chain before deciding the certificate is not valid.
		#SSLVerifyClient require
		#SSLVerifyDepth  10

		#   SSL Engine Options:
		#   Set various options for the SSL engine.
		#   o FakeBasicAuth:
		#	 Translate the client X.509 into a Basic Authorisation.  This means that
		#	 the standard Auth/DBMAuth methods can be used for access control.  The
		#	 user name is the \`one line' version of the client's X.509 certificate.
		#	 Note that no password is obtained from the user. Every entry in the user
		#	 file needs this password: \`xxj31ZMTZzkVA'.
		#   o ExportCertData:
		#	 This exports two additional environment variables: SSL_CLIENT_CERT and
		#	 SSL_SERVER_CERT. These contain the PEM-encoded certificates of the
		#	 server (always existing) and the client (only existing when client
		#	 authentication is used). This can be used to import the certificates
		#	 into CGI scripts.
		#   o StdEnvVars:
		#	 This exports the standard SSL/TLS related \`SSL_*' environment variables.
		#	 Per default this exportation is switched off for performance reasons,
		#	 because the extraction step is an expensive operation and is usually
		#	 useless for serving static content. So one usually enables the
		#	 exportation for CGI and SSI requests only.
		#   o OptRenegotiate:
		#	 This enables optimized SSL connection renegotiation handling when SSL
		#	 directives are used in per-directory context.
		#SSLOptions +FakeBasicAuth +ExportCertData +StrictRequire
		<FilesMatch "\\.(cgi|shtml|phtml|php)\$">
				SSLOptions +StdEnvVars
		</FilesMatch>
		<Directory /usr/lib/cgi-bin>
				SSLOptions +StdEnvVars
		</Directory>

		#   SSL Protocol Adjustments:
		#   The safe and default but still SSL/TLS standard compliant shutdown
		#   approach is that mod_ssl sends the close notify alert but doesn't wait for
		#   the close notify alert from client. When you need a different shutdown
		#   approach you can use one of the following variables:
		#   o ssl-unclean-shutdown:
		#	 This forces an unclean shutdown when the connection is closed, i.e. no
		#	 SSL close notify alert is send or allowed to received.  This violates
		#	 the SSL/TLS standard but is needed for some brain-dead browsers. Use
		#	 this when you receive I/O errors because of the standard approach where
		#	 mod_ssl sends the close notify alert.
		#   o ssl-accurate-shutdown:
		#	 This forces an accurate shutdown when the connection is closed, i.e. a
		#	 SSL close notify alert is send and mod_ssl waits for the close notify
		#	 alert of the client. This is 100% SSL/TLS standard compliant, but in
		#	 practice often causes hanging connections with brain-dead browsers. Use
		#	 this only for browsers where you know that their SSL implementation
		#	 works correctly.
		#   Notice: Most problems of broken clients are also related to the HTTP
		#   keep-alive facility, so you usually additionally want to disable
		#   keep-alive for those clients, too. Use variable "nokeepalive" for this.
		#   Similarly, one has to force some clients to use HTTP/1.0 to workaround
		#   their broken HTTP/1.1 implementation. Use variables "downgrade-1.0" and
		#   "force-response-1.0" for this.
		BrowserMatch "MSIE [2-6]" \
				nokeepalive ssl-unclean-shutdown \
				downgrade-1.0 force-response-1.0
		# MSIE 7 and newer should be able to use keepalive
		BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown

		<IfModule wsgi_module>
			WSGIDaemonProcess fgapiserver  user=futuregateway group=futuregateway  processes=5 threads=10 home=/home/futuregateway
			WSGIProcessGroup futuregateway
			WSGIScriptAlias /apis /home/futuregateway/FutureGateway/fgapiserver/fgapiserver.wsgi

			<Directory /home/futuregateway/FutureGateway/fgapiserver>
			  WSGIProcessGroup fgapiserver
			  WSGIApplicationGroup %{GLOBAL}
			  Order deny,allow
			  Allow from all
			  Options All
			  AllowOverride All
			  Require all granted
			</Directory>
		</IfModule>

		<IfModule mod_proxy_ajp.c>
			ProxyPass "/Shibboleth.sso/" "!"
			ProxyPass "/apis/" "!"
			ProxyPass "/saml/" "!"
			ProxyPass "/" "ajp://localhost:8009/"
		</IfModule>
                Alias "/saml" "/var/www/html/saml"
                <Directory /var/www/html/saml>
			Order deny,allow
			Allow from all
                </Directory>
                <Location /c/portal/login>
                        AuthType shibboleth
                        ShibRequestSetting requireSession 1
                        require valid-user
                </Location>
                <Location /not_authorised>
                        AuthType shibboleth
                        ShibRequestSetting requireSession 1
                        require valid-user
                </Location>
                <Location /apis/>
                        AuthType shibboleth
                        ShibRequestSetting requireSession 1
                        require valid-user
                </Location>

	</VirtualHost>
</IfModule>
EOF

cat >README <<EOF
#
# README - FutureGateway setup
#
# Author: riccardo.bruno@ct.infn.it
#
This installation provides service start/stop scripts to execute the FutureGateway
By default the installation provides a non-production environment which is good for
testing or development environments. If you want a production-like system, please
consider the following changes.

1) In /etc/init.d/futuregateway; swith-off the ENABLEFRONTEND flag to 0. This avoids
   the init script to start the APIServer font-end as a screen session

2) Configure apache to run the APIServer front-end as a WSGI process. To help configuring
   this, you can find the file fgAPIServer.conf which contains an example of apache
   configuration file
EOF

echo "Done"
