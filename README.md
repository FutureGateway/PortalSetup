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

## Script structure

There are two kind of installation scripts; hi-level and low-level.
Hi level are mentioned to cover a specific OS/Linux distro; low level scripts are used by hi-level scripts. The principal aim of hi-level scripts is to deal with mandatory packages and prepare the right configuration for low level scripts; see file: 'setup_config.sh'.

There is no priority among low level setup scripts; except for setup_FGPortal.sh that must be the 1st to be executed. However the suggested priority is:

1. `setup_FGPortal.sh` - The main script, it takes care of Tomcat, Liferay and its SDK (optional), Other Development tools (ant, maven).
2. `setup_JSAGA.sh` - This script configure the environment to host JSAGA, including binariesm, libraries and taking care of the required UnlimitedJCEPolicy accordingly to the current JAVA version
3. `setup_GridEngine.sh` - This installs the Grid and Cloud Engine component (if requested)
4. `setup_OCCI.sh` - This is in charge to prepare the GSI environment (VOMS included) and the OCCI CLI interface. It may use the fed cloud installation or a manual setup (not really suggested, but necessary for CentOS7).
5. `setup_fgService.sh` - For OSes supporting the /etc/init.d service support this installs the service control script

All setup scripts have the same structure. Each installation step is managed by a dedicated bash function and each function can execute only once even running the setup script more times. This protection method is managed by a setup file named: '.fgSetup'.
The sequence of these function is managed by the scrip body at the bottom of the file in the form of an and-chain:

  `script_function_1 && script_function_2 && ... && script_function_n`

So that if one of the function fails the script terminates giving the opportunity to fix the issue and restart the installation.
