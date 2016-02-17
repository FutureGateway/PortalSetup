# PortalSetup
Script collection for automatic installation of the FutureGateway portal and its development environment.
All setup files at this level are meant to support the following platforms

* MacOSX 10.11; it requires brew
* EL6/7 Tested with CentOS6
* Debian Tested with Ubuntu

The platform should be automatically identified while the script runs.
Each setup file has the form `setup_*`, where `*` refers to a specific component and some of them require to be executed as root or by sudo. 
Please notice that OS specific intallation scripts are collected inside dedicated directories.

## Usage
Each script has several configuration options at the top of the script. These values can be overridden specifying values in `setup_config.sh` script.
Once configured values in setup script or at the top of the script, just execute the script with `./setup_<component>`.
