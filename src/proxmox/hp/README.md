## HP RAID Status

This folder contains the scripts, service and timer needed for proxmox to push it's raid status to home assistant over MQTT.

### Installation

To install this tool you can run the following command:

`wget -qO https://github.com/DhrMaes/HomeLab/raw/main/install-hpraid-monitor.sh | bash`

### How it works

It will install the following components:
- mosquitto-clients
- ssacli

The `mosquitto-client` is used to publish over mqtt. The `ssacli` is the hp cli tool to get the status of your drives from the RAID controller.

It will then setup a service `systemd` service that execute the script that runs the status command for the raid controller and the drives and pushes that over mqtt to home assistant. It will also setup a timer that by default will execute that service every 5 minutes. You can change the timer in that file.

During the installation you will be prompted to fill in the ip, port, username and password for the mqtt broker. That will be saved in an environment file that is configured in the service. That way the actual script doesn't need hard-coded credentials.