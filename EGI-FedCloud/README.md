# EGI-FedCloud
The FutureGateway portal can be instantiated by an existing EGI FedCloud virtual appliance named: [FutureGateway][FGAPPDB].
The virtual appliance is based on an Ubuntu-server 14.04 and it requires a specific cloud-init' user-data file in order to setup it properly.
The principal aim of the FutureGateway virtual appliance is to allow Science Gateway application developers to make practice with FutureGateway REST APIs without takin care of the whole system intallation.

Below the commands to correctly instantiate the VM:

`OCCI_RES=$(occi -e $OCCI_ENDPOINT --auth x509 --user-cred $USER_CRED --voms $VOMS --action create --resource compute --mixin os_tpl#$OS_TPL --mixin resource_tpl#m1-large --attribute occi.core.title="fgOCCI" --context user_data="file://$HOME/userdata.txt"); echo "Resourcce: $OCCI_RES"`

In case it is needed to assign a public IP to the given resource:

`occi --endpoint $OCCI_ENDPOINT --auth x509 --user-cred $USER_CRED --voms $VOMS --action link --resource $OCCI_RES --link /network/public`

# Suggested procedures
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
Detach with <ctrl-a><ctrl-d>
Reattach the front-end process anytime with `screen -r fgAPIServer`

## APIServer Daemon
The API Server Daemon conists of a web application, so that it is necessary to startup the application server (Tomcat). The virtual appliance is already configured to install and execute the daemon during the application server startup.
To startup the application server you may use the standard scripts provided with Tomcat or you may use the 'start\_tomcat' utility:

* Startup application server:
`start_tomcat`

* Monitor the APIServer daemon:
`tail -f $CATALINA_HOME/logs/catalina.out`
It is important during development phases to constatly monitor the APIServer daemon activity, to accomplish that it is enough to have a look inside the application server log file.

[FGAPPDB]: <https://appdb.egi.eu/store/vappliance/futuregateway>
[FGAPIFE]: <https://github.com/FutureGateway/fgAPIServer>
[FGASRVD]: <https://github.com/FutureGateway/APIServerDaemon>
