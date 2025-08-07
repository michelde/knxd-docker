#!/bin/sh

# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to validate KNX address format (area.line.device)
validate_knx_address() {
    local address="$1"
    local name="$2"
    
    if ! echo "$address" | grep -qE '^[1-9]|1[0-5]\.[1-9]|1[0-5]\.[1-9][0-9]|[1-2][0-5][0-5]$'; then
        log "ERROR: Invalid $name format: $address"
        log "Expected format: area.line.device (1-15.1-15.1-255)"
        return 1
    fi
    return 0
}

# Function to validate client address format (start:count)
validate_client_address() {
    local address="$1"
    
    if ! echo "$address" | grep -qE '^[1-9]|1[0-5]\.[1-9]|1[0-5]\.[1-9][0-9]|[1-2][0-5][0-5]:[1-9][0-9]*$'; then
        log "ERROR: Invalid CLIENT_ADDRESS format: $address"
        log "Expected format: start_address:count (e.g., 1.5.2:10)"
        return 1
    fi
    return 0
}

# Function to validate IP address format
validate_ip_address() {
    local ip="$1"
    local name="$2"
    
    if ! echo "$ip" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
        log "ERROR: Invalid $name format: $ip"
        log "Expected format: xxx.xxx.xxx.xxx"
        return 1
    fi
    
    # Check each octet is between 0-255
    for octet in $(echo "$ip" | tr '.' ' '); do
        if [ "$octet" -gt 255 ] || [ "$octet" -lt 0 ]; then
            log "ERROR: Invalid $name: $ip (octet $octet out of range 0-255)"
            return 1
        fi
    done
    return 0
}

# Function to validate port number
validate_port() {
    local port="$1"
    local name="$2"
    
    if ! echo "$port" | grep -qE '^[0-9]+$' || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log "ERROR: Invalid $name: $port"
        log "Expected: number between 1-65535"
        return 1
    fi
    return 0
}

# Function to validate device path exists
validate_device_path() {
    local device="$1"
    local name="$2"
    
    if [ ! -e "$device" ]; then
        log "WARNING: Device $name does not exist: $device"
        log "This may cause knxd to fail to start"
        return 1
    fi
    
    if [ ! -r "$device" ] || [ ! -w "$device" ]; then
        log "WARNING: Device $name may not have proper permissions: $device"
        log "Consider checking device permissions"
    fi
    return 0
}

log "Starting knxd-docker initialization..."

# Set default values for optional parameters
log "Setting default values for optional parameters..."

# Set default debug level if not provided
if [ -z "$DEBUG_ERROR_LEVEL" ]; then
    DEBUG_ERROR_LEVEL="error"
    log "Using default DEBUG_ERROR_LEVEL: $DEBUG_ERROR_LEVEL"
fi

# Set default filters if not provided
if [ -z "$FILTERS" ]; then
    FILTERS="single"
    log "Using default FILTERS: $FILTERS"
fi

# Set default NAT setting if not provided
if [ -z "$NAT" ]; then
    NAT="false"
    log "Using default NAT: $NAT"
fi

# Set default destination port for IP-based interfaces
if [ -z "$DEST_PORT" ]; then
    DEST_PORT="3671"
    log "Using default DEST_PORT: $DEST_PORT"
fi

# Export variables so they're available for envsubst
export DEBUG_ERROR_LEVEL
export FILTERS
export NAT
export DEST_PORT

# Validate core required environment variables
VALIDATION_FAILED=0

# Validate ADDRESS
if [ -z "$ADDRESS" ]; then
    log "ERROR: ADDRESS environment variable is required"
    VALIDATION_FAILED=1
else
    log "Validating ADDRESS: $ADDRESS"
    if ! validate_knx_address "$ADDRESS" "ADDRESS"; then
        VALIDATION_FAILED=1
    fi
fi

# Validate CLIENT_ADDRESS
if [ -z "$CLIENT_ADDRESS" ]; then
    log "ERROR: CLIENT_ADDRESS environment variable is required"
    VALIDATION_FAILED=1
else
    log "Validating CLIENT_ADDRESS: $CLIENT_ADDRESS"
    if ! validate_client_address "$CLIENT_ADDRESS"; then
        VALIDATION_FAILED=1
    fi
fi

# Validate INTERFACE
if [ -z "$INTERFACE" ]; then
    log "ERROR: INTERFACE environment variable is required"
    VALIDATION_FAILED=1
else
    log "Validating INTERFACE: $INTERFACE"
    case "$INTERFACE" in
        tpuart|usb|ipt|ft12|ft12cemi|ncn5120|dummy)
            log "Interface type '$INTERFACE' is supported"
            ;;
        *)
            log "ERROR: Unsupported INTERFACE: $INTERFACE"
            log "Supported interfaces: tpuart, usb, ipt, ft12, ft12cemi, ncn5120, dummy"
            VALIDATION_FAILED=1
            ;;
    esac
fi

# Interface-specific validation
if [ "$INTERFACE" = "tpuart" ] || [ "$INTERFACE" = "ft12" ] || [ "$INTERFACE" = "ft12cemi" ] || [ "$INTERFACE" = "ncn5120" ]; then
    if [ -z "$DEVICE" ]; then
        log "ERROR: DEVICE environment variable is required for $INTERFACE interface"
        VALIDATION_FAILED=1
    else
        log "Validating DEVICE: $DEVICE"
        validate_device_path "$DEVICE" "DEVICE"
    fi
fi

if [ "$INTERFACE" = "usb" ]; then
    if [ -z "$USB_DEVICE" ] && [ -z "$USB_BUS" ]; then
        log "ERROR: Either USB_DEVICE or USB_BUS environment variable is required for USB interface"
        VALIDATION_FAILED=1
    fi
    
    if [ -n "$USB_DEVICE" ]; then
        log "Validating USB_DEVICE: $USB_DEVICE"
        validate_device_path "$USB_DEVICE" "USB_DEVICE"
    fi
fi

if [ "$INTERFACE" = "ipt" ] || [ "$INTERFACE" = "tpuart-ip" ] || [ "$INTERFACE" = "ncn5120-ip" ]; then
    if [ -z "$IP_ADDRESS" ]; then
        log "ERROR: IP_ADDRESS environment variable is required for $INTERFACE interface"
        VALIDATION_FAILED=1
    else
        log "Validating IP_ADDRESS: $IP_ADDRESS"
        if ! validate_ip_address "$IP_ADDRESS" "IP_ADDRESS"; then
            VALIDATION_FAILED=1
        fi
    fi
    
    if [ -n "$DEST_PORT" ]; then
        log "Validating DEST_PORT: $DEST_PORT"
        if ! validate_port "$DEST_PORT" "DEST_PORT"; then
            VALIDATION_FAILED=1
        fi
    fi
fi

# Validate optional DEBUG_ERROR_LEVEL
if [ -n "$DEBUG_ERROR_LEVEL" ]; then
    log "Validating DEBUG_ERROR_LEVEL: $DEBUG_ERROR_LEVEL"
    case "$DEBUG_ERROR_LEVEL" in
        error|warning|info|debug|trace)
            log "Debug level '$DEBUG_ERROR_LEVEL' is valid"
            ;;
        *)
            log "WARNING: Unknown DEBUG_ERROR_LEVEL: $DEBUG_ERROR_LEVEL"
            log "Valid levels: error, warning, info, debug, trace"
            ;;
    esac
fi

# Validate optional FILTERS
if [ -n "$FILTERS" ]; then
    log "Validating FILTERS: $FILTERS"
    case "$FILTERS" in
        single|none)
            log "Filter setting '$FILTERS' is valid"
            ;;
        *)
            log "WARNING: Unknown FILTERS setting: $FILTERS"
            log "Valid settings: single, none"
            ;;
    esac
fi

# Validate optional NAT setting
if [ -n "$NAT" ]; then
    log "Validating NAT: $NAT"
    case "$NAT" in
        true|false)
            log "NAT setting '$NAT' is valid"
            ;;
        *)
            log "WARNING: Invalid NAT setting: $NAT"
            log "Valid settings: true, false"
            ;;
    esac
fi

# Exit if validation failed
if [ $VALIDATION_FAILED -eq 1 ]; then
    log "ERROR: Configuration validation failed. Please check your environment variables."
    log "Refer to the documentation for proper configuration examples."
    exit 1
fi

log "Configuration validation passed successfully"

# Replace placeholders with environment variable values
log "Generating knxd configuration file..."
envsubst < "/etc/knxd-template.ini" > "/etc/knxd.ini"

# Ensure the output file has the correct permissions
chmod 644 /etc/knxd.ini

# Log the generated configuration for debugging
log "Generated configuration:"
cat /etc/knxd.ini

log "knxd-docker initialization completed successfully"

# Execute the command passed as arguments (from CMD in Dockerfile)
log "Starting knxd with command: $*"
exec "$@"
