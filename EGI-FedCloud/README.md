# EGI-FedCloud
The FutureGateway portal can be instantiated by an existing EGI FedCloud virtual appliance named: [FutureGateway][FGAPPDB].
The virtual appliance is based on an Ubuntu-server 14.04 and it requires a specific cloud-init' user-data file in order to setup it properly.

Below the commands to correctly instantiate the VM:

`OCCI_RES=$(occi -e $OCCI_ENDPOINT --auth x509 --user-cred $USER_CRED --voms $VOMS --action create --resource compute --mixin os_tpl#$OS_TPL --mixin resource_tpl#m1-large --attribute occi.core.title="fgOCCI" --context user_data="file://$HOME/userdata.txt"); echo "Resourcce: $OCCI_RES"`

In case it is needed to assign a public IP to the given resource:

`occi --endpoint $OCCI_ENDPOINT --auth x509 --user-cred $USER_CRED --voms $VOMS --action link --resource $OCCI_RES --link /network/public`


[FGAPPDB]: <https://appdb.egi.eu/store/vappliance/futuregateway>
