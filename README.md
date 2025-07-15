# Dell R730 ESXi NVIDIA VM Fan Control

> [!Important]
> This project provides scripts to control the fan speeds of a Dell PowerEdge R730 server based on GPU and CPU temperatures. It uses IPMI commands to adjust fan speeds dynamically.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Configuration](#configuration)
3. [Scripts](#scripts)
4. [Setup as a System Service](#setup-as-a-system-service)
5. [How It Works](#how-it-works)
6. [Example Commands](#example-commands)
7. [View Logs](#view-logs)
8. [Troubleshooting](#troubleshooting)
9. [License](#license)



## Prerequisites

- ```ipmitool```: Install with ```sudo apt install ipmitool```
- ```nvidia-smi```: Comes with NVIDIA drivers or ```sudo apt install nvidia-utils-xxx```

## Configuration

Edit the ```ipmi_config.cfg``` file to set your IPMI host, user, password, and temperature thresholds.

```cfg
# DELL IPMI Configuration
IPMI_HOST=192.168.1.xxx
IPMI_USER=root
IPMI_PASSWORD=your-password
IPMI_YKEY=0000000000000000000000000000000000000000

# Creates a linear function between the two points
MIN_FAN_SPEED=13
TEMP_LOW_THRESHOLD=45

MAX_FAN_SPEED=100
TEMP_HIGH_THRESHOLD=70
```

## Scripts

```fan-control.sh```
This script continuously monitors the temperatures of the GPUs and CPUs and adjusts the fan speeds accordingly.

```reset.sh```
This script resets the fan control to automatic mode.

```status.sh```
This script displays the current temperatures of the GPUs and CPUs.

## Setup as a System Service

> [!Tip]
> To set up the fan control script as a systemd service, follow these steps:

1. **Install the Service** - Run the ```install-system-service.sh``` script to install the service.

```shell
chmod +x install-system-service.sh
sudo ./install-system-service.sh
```

2. **Uninstall the Service** - If you need to uninstall the service, run the ```uninstall-service.sh``` script.

```shell
chmod +x uninstall-service.sh
sudo ./uninstall-service.sh
```

## How It Works

1. **Configuration Loading**
   * Each script loads the configuration from ```ipmi_config.cfg```
2. **Temperature Monitoring**
   * The ```fan-control.sh``` script uses ```nvidia-smi``` to get GPU temperatures and ```ipmitool``` to get CPU temperatures
3. **Fan Speed Adjustment**
    * Based on the highest temperature detected, the script sets the fan speed using IPMI commands.
4. **Service Management**
    * The ```install-system-service.sh``` script sets up the ```fan-control.sh``` script as a ```systemd``` service, ensuring it starts on boot and restarts if it fails.

## Example Commands

* Check Service Status
```shell
sudo systemctl status fan-control.service
```

* Start Service
```shell
sudo systemctl start fan-control.service
```

* Stop Service
```shell
sudo systemctl stop fan-control.service
```

## View Logs

> [!Important]
> ```sudo tail -f /var/log/fan-control.log```

## 🗺️ Roadmap
 - [ ] Fix folder structure
 - [ ] Run logs & output debug lines to `systemd` - *still need to learn how that works*


## Troubleshooting

* Ensure all required packages are installed.
* Verify the IPMI configuration in ```ipmi_config.cfg```.
* Check the logs at ```/var/log/fan-control.log``` for any errors.

## License

> This project is licensed under the MIT License.
