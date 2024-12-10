#!/bin/sh

# Replace placeholders with environment variable values
envsubst < "/etc/knxd-template.ini" > "/etc/knxd.ini"

# Ensure the output file has the correct permissions
chmod 644 /etc/knxd.ini