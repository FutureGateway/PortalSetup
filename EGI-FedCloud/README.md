# EGI-FedCloud
The FutureGateway portal can be instantiated by an existing EGI FedCloud virtual appliance named: [FutureGateway][FGAPPDB].
The virtual appliance is based on an Ubuntu-server 14.04 and it requires a specific cloud-init' user-data file in order to setup it properly.
The principal aim of the FutureGateway virtual appliance is to allow Science Gateway application developers to make practice with FutureGateway REST APIs without takin care of the whole system intallation.

Below the commands to correctly instantiate the VM:

`OCCI_RES=$(occi -e $OCCI_ENDPOINT --auth x509 --user-cred $USER_CRED --voms $VOMS --action create --resource compute --mixin os_tpl#$OS_TPL --mixin resource_tpl#$RESOURCE_TPL --attribute occi.core.title="fgocci2" --context user_data="file://$HOME/userdata.txt"); echo "Resourcce: $OCCI_RES"`

The contextualization file `userdata.txt` has to be customized before to execute the `occi` command line. In particular the user must provide its own ssh public key under cloud-init key `ssh-authorized-keys`. Another point to customize is inside the `write_files` directive for the file `/root/installFG.sh`. The following sed commands must be configured:

`sed s/TOMCATUSR=\"tomcat\"/TOMCATUSR=\"<tomcat_admin_user>\"/` 
`sed s/TOMCATPAS=\"tomcat\"/TOMCATUSR=\"<tomcat_admin_password>\"/`

replace text inside the `<...>` brackets with your preferred Tomcat service admin username and password.
Further and more sofisticated customizations could be done in the same fashion mofifying the downloaded script `fgSetup.sh`

In case it is needed to assign a public IP to the given resource:

`occi --endpoint $OCCI_ENDPOINT --auth x509 --user-cred $USER_CRED --voms --action link --resource $OCCI_RES --link /network/public`

# Suggested procedures
The instantiated VM will start to install automatically the whole FutureGateway environment extracting anything from GITHub, so that fresh installations will contain the latest available packages version. To know about the end of the installation procedure, please check the existence of file `/home/futuregateway/.installingFG.` If the file exists the installation procedure is in progress or finished otherwise. To check about installation details: `sudo su -` and then `tail -f install.out install.err`.
Once finished the installation it is important to exit from any ssh connection active before the installation procedure and re-log again. During the re-connection, ssh will recognize a host identification change, then proceed to accept the new identity.

In order to test/use FutureGateway REST APIs, several services should be started before; in particular:

1. The REST APIs [front-end][FGAPIFE]
2. The API [ServerDaemon][FGASRVD]

The installation procedure provides the 'futuregateway' service control script in `/etc/init.d` directory, to control the futuregateway activity. Use:
`/etc/init.d/futuregateway start|stop|restart|status` in order to respectively start, stop, restart or get the current status of futuregateway services. For production environments is suggested to disable the front-end management switching off a flag inside the service control script. In case of production environment the front-end execution will be in charge of wsgi configuration inside the proper apache conf file.

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
`start_tomcat`. To manage daemon activity you can use the Tomcat manager front-end with `http://<VM_IP>:8080/manager` (default credentials are tomcat/tomcat), however for security reasons, you can change these value in the contextualization script.To stop Tomcat you can use `stop_tomcat` then please verify its java process with `ps -ef | grep tomcat | grep java` if the process still perist you may use '`killjava` command.

* Monitor the APIServer daemon app server activity:
`tail -f $CATALINA_HOME/logs/catalina.out`
It is important during development phases to constatly monitor the APIServer daemon activity, to accomplish that it is enough to have a look inside the application server log file.

* Monitor the APIServer daemon activity:
`tail -f $FGLOCATION/apache-tomcat-8.0.26/webapps/APIServerDaemon/WEB-INF/logs/APIServerDaemon.log`

* Monitor the GridEngine activity:
`tail -f $FGLOCATION/apache-tomcat-8.0.26/webapps/APIServerDaemon/WEB-INF/logs/GridEngineLog.log`

## Security considerations
Please notice that for security reasons userdata.txt file must be modified specifying your own tomcat admin user name and password.
At the end of the installation procedure, please setup a strong futuregateway password and remove the `NOPASSWD` flag in file `/etc/sudoers` to improve the security.
Although the VM has been configured to limit hackers exposure, it is warmly suggested to comply with the EGI FedCloud [directives][EGIFCDR]

[FGAPPDB]: <https://appdb.egi.eu/store/vappliance/futuregateway>
[FGAPIFE]: <https://github.com/FutureGateway/fgAPIServer>
[FGASRVD]: <https://github.com/FutureGateway/APIServerDaemon>
[EGIFCDR]: <https://wiki.egi.eu/wiki/Virtual_Machine_Image_Endorsement#Hardening_guidelines>
