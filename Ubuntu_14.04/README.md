# Ubuntu 14.04
In this section there are scripts written for the specific Ubuntu 14.04 OS release.

* `fgSetup.sh` script can be used inside a minimal Ubuntu installation
* `docker-setup.sh` script can be used inside a docker ubuntu template; this script prepares the environment and then uses fgSetup.sh

# fgSetup
In order to install the FutureGateway, just execute as root user:

```sh
# IP=$(ifconfig | grep  -A 2 eth0 | grep inet\ addr | awk -F':' '{ print $2 }' | awk '{ print $1 }' | xargs echo)
# echo "nameserver 8.8.8.8" >> /etc/resolv.conf
# echo "nameserver 8.8.4.4" >> /etc/resolv.conf
# echo "$IP    futuregateway" >> /etc/hosts
# adduser --disabled-password --gecos "" futuregateway 
# mkdir -p /home/futuregateway/.ssh
# chown futuregateway:futuregateway /home/futuregateway/.ssh
# wget https://github.com/FutureGateway/PortalSetup/raw/master/Ubuntui_14.04/fgSetup.sh
# chmod +x fgSetup.sh
# cat /dev/zero | ssh-keygen -q -N ""
# cat /root/.ssh/id_rsa.pub >> /home/futuregateway/.ssh/authorized_keys
# echo "#FGSetup remove the following after installation" >> /etc/sudoers
# echo "ALL  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
# ./fgSetup.sh futuregateway futuregateway <your ssh port> $(cat /root/.ssh/id_rsa.pub)
```
Before to execute `fgSetup.sh` it is recommended to open it and verify inside its content, the default settings specifyed while generating file setup_config.sh. Executing the last statement above, the installation procedure should start and it requires a while to complete.

# Suggested procedures
The installation scritps will instantiate the full FutureGateway environment extracting anything from GITHub, so that fresh installations will contain the latest available packages version. To know about the status or the end of the installation procedure, please check the output of the scripit. 
Once finished the installation it is important to exit from any ssh connection active before the installation procedure and re-log again. During the re-connection, ssh will recognize a host identification change, then proceed to accept the new identity. In case the script have been executed from root it is enough to change the user with `su - futuregateway`.

In order to test FutureGateway REST APIs, several services should be started before; in particular:

1. The REST APIs [front-end][FGAPPDB]
2. The API [ServerDaemon][FGASRVD]

## REST APIs front-end
In a production environment the API server front-end must be configured with a dedicated wsgi configuration inside the web server. However for testing purposes the front-end can be executed in stand-alone mode with the following set of commands:

* Instantiate a screen section:
`screen -S fgAPIServer`
* Execute the API REST front-end:
`cd $FGLOCATION/fgAPIServer`
`cd $FGLOCATION/fgAPIServer`
`./fgapiserver.py`
Detach with \<ctrl-a\>\<ctrl-d\>
Reattach the front-end process anytime with `screen -r fgAPIServer`

## APIServer Daemon
The API Server Daemon conists of a web application, so that it is necessary to startup the application server (Tomcat). The virtual appliance is already configured to install and execute the daemon during the application server startup.
To startup the application server you may use the standard scripts provided with Tomcat or you may use the 'start\_tomcat' utility:

* Startup application server:
`start_tomcat`. To manage daemon activity you can use the Tomcat manager front-end with `http://<VM_IP>:8080/manager` (default credentials are tomcat/tomcat).To stop Tomcat you can use `stop_tomcat` then please verify its java process with `ps -ef | grep tomcat | grep java` if the process still perist you may use '`killjava` command.

* Monitor the APIServer daemon app server activity:
`tail -f $CATALINA_HOME/logs/catalina.out`
It is important during development phases to constatly monitor the APIServer daemon activity, to accomplish that it is enough to have a look inside the application server log file.

* Monitor the APIServer daemon activity:
`tail -f $FGLOCATION/apache-tomcat-8.0.26/webapps/APIServerDaemon/WEB-INF/logs/APIServerDaemon.log`

* Monitor the GridEngine activity:
t.b.d.

## Security considerations
Although the VM has been configured to limit hackers exposure, it is warmly suggested to comply with the EGI FedCloud [directives][EGIFCDR]

[FGAPIFE]: <https://github.com/FutureGateway/fgAPIServer>
[FGASRVD]: <https://github.com/FutureGateway/APIServerDaemon>
[EGIFCDR]: <https://wiki.egi.eu/wiki/Virtual_Machine_Image_Endorsement#Hardening_guidelines>
