#!/bin/bash

# Debug log file
DEBUG_LOG="/var/log/fan-control-debug.log"

# Load configuration file
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
CONFIG_FILE="${SCRIPT_DIR}/fan-control.cfg"

echo "Starting fan-control script..." | tee -a $DEBUG_LOG

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found!" | tee -a $DEBUG_LOG
    exit 1
fi

echo "Loading configuration file..." | tee -a $DEBUG_LOG
source "$CONFIG_FILE"


# Construct the IPMI command with parameters from the config file
IPMI_COMMAND="ipmitool -I lanplus -H $IPMI_HOST -U $IPMI_USER -P $IPMI_PASSWORD -y $IPMI_YKEY"

# Load IPMI control script (ensure the path is correct)
echo "Running take-control.sh..." | tee -a $DEBUG_LOG
/opt/fan-control/take-control.sh >> $DEBUG_LOG 2>&1

# Function to keep logs for only 1 hour
manage_logs() {
    find $DEBUG_LOG -type f -mmin +60 -exec rm {} \;
}

#Initialize control
echo "Setting fans to manual control" | tee -a $DEBUG_LOG
$IPMI_COMMAND raw 0x30 0x30 0x01 0x00

# Start an infinite loop to check temperatures and adjust fan speed every 10 seconds
while true; do
    manage_logs

    echo "Checking temperatures..." | tee -a $DEBUG_LOG
    
    # Get GPU temperatures using nvidia-smi
    gpu_temp1=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits -i 0 2>> $DEBUG_LOG)
    gpu_temp2=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits -i 1 2>> $DEBUG_LOG)
	
	# Determine the highest GPU temperature
    max_gpu_temp=$((gpu_temp1 > gpu_temp2 ? gpu_temp1 : gpu_temp2))
	
	echo -e "GPU1: ${gpu_temp1}°C\tGPU2: ${gpu_temp2}°C\tMax: ${max_gpu_temp}°C" | tee -a $DEBUG_LOG
	
    # Get CPU temperatures using the provided command for sensor IDs 0Eh and 0Fh
	cpu_temp1=$(snmpwalk -v2c -c public 10.0.0.106 .1.3.6.1.4.1.674.10892.5.4.700.20.1.6.1.3 | sed -n 's/.*INTEGER: \([0-9]*\)/\1/p' | awk '{print $1 / 10}')
	cpu_temp2=$(snmpwalk -v2c -c public 10.0.0.106 .1.3.6.1.4.1.674.10892.5.4.700.20.1.6.1.4 | sed -n 's/.*INTEGER: \([0-9]*\)/\1/p' | awk '{print $1 / 10}')

    # Determine the highest CPU temperature
    max_cpu_temp=$((cpu_temp1 > cpu_temp2 ? cpu_temp1 : cpu_temp2))
	
	echo -e "CPU0: ${cpu_temp1}°C\tCPU1: ${cpu_temp2}°C\tMax: ${max_cpu_temp}°C" | tee -a $DEBUG_LOG
    
	
	max_temp=$((max_gpu_temp > max_cpu_temp ? max_gpu_temp : max_cpu_temp))
	
    # Determine the appropriate fan speed based on GPU temperature thresholds
	m=$(echo "scale=2; ($MAX_FAN_SPEED - $MIN_FAN_SPEED)/($TEMP_HIGH_THRESHOLD - $TEMP_LOW_THRESHOLD)" | bc)
	c=$(echo "$MIN_FAN_SPEED - $m * $TEMP_LOW_THRESHOLD" | bc)
	fan_speed=$(echo "$m * $max_temp + $c" | bc)
	
	fan_speed=${fan_speed%%.*}  # Strip decimals to get an integer (optional, for hardware compatibility)
	
	# If result is empty or invalid (e.g., just '-', '', etc.), default to 0
	if ! [[ "$fan_speed" =~ ^-?[0-9]+$ ]]; then
		fan_speed=0
	fi

	# Clamp negatives to 0
	if [ "$fan_speed" -lt 0 ]; then
		fan_speed=0
	fi

	# clamp fan speed to the lower or upper point
	if [ "$fan_speed" -lt "$MIN_FAN_SPEED" ]; then
        fan_speed=$MIN_FAN_SPEED
    fi
	
	if [ "$fan_speed" -gt "$MAX_FAN_SPEED" ]; then
		fan_speed=$MAX_FAN_SPEED
	fi

    fan_speed_hex=$(printf '0x%02x' $fan_speed)
		
    echo "Setting fan speed to $fan_speed% (hex: $fan_speed_hex)" | tee -a $DEBUG_LOG

    # Apply the fan speed setting using remote IPMI command
    $IPMI_COMMAND raw 0x30 0x30 0x02 0xff "$fan_speed_hex" >> $DEBUG_LOG 2>&1

    # Error checking based on the temperature and fan speed
	
    #if [ "$fan_speed" -eq "$MIN_FAN_SPEED" ] && [ "$max_temp" -gt 75 ]; then
    #    echo "ERROR: GPU temperature exceeded 75°C while fan speed was low ($fan_speed%)" | systemd-cat -p err | tee -a $DEBUG_LOG
    #elif [ "$fan_speed" -eq "$MID_FAN_SPEED" ] && [ "$max_temp" -gt 85 ]; then
    #    echo "ERROR: GPU temperature exceeded 85°C while fan speed was mid ($fan_speed%)" | systemd-cat -p err | tee -a $DEBUG_LOG
    #fi

    # Wait for 10 seconds before the next check
    sleep 10
done
