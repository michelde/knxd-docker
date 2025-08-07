#!/bin/bash

# Health check script for knxd-docker
# Usage: ./scripts/health-check.sh [CONTAINER_NAME]

set -euo pipefail

# Default values
CONTAINER_NAME="${1:-knxd}"
TIMEOUT="${TIMEOUT:-30}"
VERBOSE="${VERBOSE:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [CONTAINER_NAME]

Arguments:
  CONTAINER_NAME  Name of the knxd container (default: knxd)

Environment Variables:
  TIMEOUT         Timeout for checks in seconds (default: 30)
  VERBOSE         Enable verbose output (default: false)

Examples:
  # Basic health check
  $0

  # Check specific container
  $0 my-knxd-container

  # Verbose output with custom timeout
  VERBOSE=true TIMEOUT=60 $0

  # Show this help
  $0 --help
EOF
}

# Check for help flag
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_usage
    exit 0
fi

# Function to check if container exists and is running
check_container_status() {
    log_info "Checking container status..."
    
    if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        if docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            log_error "Container '$CONTAINER_NAME' exists but is not running"
            log_verbose "Container status: $(docker ps -a --filter "name=${CONTAINER_NAME}" --format "{{.Status}}")"
            return 1
        else
            log_error "Container '$CONTAINER_NAME' does not exist"
            return 1
        fi
    fi
    
    log_success "Container '$CONTAINER_NAME' is running"
    log_verbose "Container ID: $(docker ps --filter "name=${CONTAINER_NAME}" --format "{{.ID}}")"
    return 0
}

# Function to check knxd process
check_knxd_process() {
    log_info "Checking knxd process..."
    
    if docker exec "$CONTAINER_NAME" ps aux | grep -v grep | grep -q knxd; then
        log_success "knxd process is running"
        if [[ "$VERBOSE" == "true" ]]; then
            log_verbose "Process details:"
            docker exec "$CONTAINER_NAME" ps aux | grep -v grep | grep knxd
        fi
        return 0
    else
        log_error "knxd process is not running"
        return 1
    fi
}

# Function to check network ports
check_network_ports() {
    log_info "Checking network ports..."
    
    local tcp_port_ok=false
    local udp_port_ok=false
    
    # Check TCP port 6720
    if docker exec "$CONTAINER_NAME" netstat -ln | grep -q ":6720.*LISTEN"; then
        log_success "TCP port 6720 is listening"
        tcp_port_ok=true
    else
        log_warning "TCP port 6720 is not listening"
    fi
    
    # Check UDP port 3671
    if docker exec "$CONTAINER_NAME" netstat -ln | grep -q ":3671.*udp"; then
        log_success "UDP port 3671 is open"
        udp_port_ok=true
    else
        log_warning "UDP port 3671 is not open"
    fi
    
    if [[ "$tcp_port_ok" == "true" || "$udp_port_ok" == "true" ]]; then
        return 0
    else
        log_error "No expected ports are listening"
        return 1
    fi
}

# Function to check configuration file
check_configuration() {
    log_info "Checking configuration file..."
    
    if docker exec "$CONTAINER_NAME" test -f /etc/knxd.ini; then
        log_success "Configuration file exists"
        
        if [[ "$VERBOSE" == "true" ]]; then
            log_verbose "Configuration content:"
            docker exec "$CONTAINER_NAME" cat /etc/knxd.ini
        fi
        
        # Check if configuration has required sections
        if docker exec "$CONTAINER_NAME" grep -q "\[main\]" /etc/knxd.ini; then
            log_success "Configuration file has main section"
        else
            log_warning "Configuration file missing main section"
        fi
        
        return 0
    else
        log_error "Configuration file /etc/knxd.ini does not exist"
        return 1
    fi
}

# Function to check container logs for errors
check_container_logs() {
    log_info "Checking container logs for errors..."
    
    local error_count
    error_count=$(docker logs "$CONTAINER_NAME" --tail 50 2>&1 | grep -i error | wc -l)
    
    if [[ "$error_count" -eq 0 ]]; then
        log_success "No errors found in recent logs"
    else
        log_warning "Found $error_count error(s) in recent logs"
        
        if [[ "$VERBOSE" == "true" ]]; then
            log_verbose "Recent errors:"
            docker logs "$CONTAINER_NAME" --tail 50 2>&1 | grep -i error | tail -5
        fi
    fi
    
    return 0
}

# Function to test KNX connectivity (basic)
test_knx_connectivity() {
    log_info "Testing basic KNX connectivity..."
    
    # Try to connect to the KNX daemon
    if timeout "$TIMEOUT" docker exec "$CONTAINER_NAME" sh -c "echo 'test' | nc -w 5 127.0.0.1 6720" >/dev/null 2>&1; then
        log_success "KNX daemon is accepting connections"
        return 0
    else
        log_warning "Could not connect to KNX daemon (this may be normal depending on configuration)"
        return 0  # Don't fail the health check for this
    fi
}

# Function to check resource usage
check_resource_usage() {
    log_info "Checking resource usage..."
    
    local stats
    stats=$(docker stats "$CONTAINER_NAME" --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}" | tail -n 1)
    
    if [[ -n "$stats" ]]; then
        log_success "Resource usage: $stats"
        
        # Extract CPU percentage (remove % sign)
        local cpu_percent
        cpu_percent=$(echo "$stats" | awk '{print $1}' | sed 's/%//')
        
        if (( $(echo "$cpu_percent > 80" | bc -l) )); then
            log_warning "High CPU usage: ${cpu_percent}%"
        fi
    else
        log_warning "Could not retrieve resource usage"
    fi
    
    return 0
}

# Main health check function
run_health_check() {
    log_info "Starting health check for container '$CONTAINER_NAME'"
    echo "=================================================="
    
    local checks_passed=0
    local total_checks=6
    
    # Run all checks
    if check_container_status; then ((checks_passed++)); fi
    echo ""
    
    if check_knxd_process; then ((checks_passed++)); fi
    echo ""
    
    if check_network_ports; then ((checks_passed++)); fi
    echo ""
    
    if check_configuration; then ((checks_passed++)); fi
    echo ""
    
    if check_container_logs; then ((checks_passed++)); fi
    echo ""
    
    if test_knx_connectivity; then ((checks_passed++)); fi
    echo ""
    
    check_resource_usage
    echo ""
    
    # Summary
    echo "=================================================="
    log_info "Health check summary: $checks_passed/$total_checks checks passed"
    
    if [[ "$checks_passed" -eq "$total_checks" ]]; then
        log_success "All health checks passed! Container is healthy."
        return 0
    elif [[ "$checks_passed" -ge 4 ]]; then
        log_warning "Most health checks passed. Container is likely healthy but may have minor issues."
        return 0
    else
        log_error "Multiple health checks failed. Container may have serious issues."
        return 1
    fi
}

# Run the health check
run_health_check
