#!/bin/bash

# Start tailscaled in the background
# The --tun=userspace-networking flag is CRITICAL for environments that don't have /dev/net/tun
/app/tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &

# Give tailscaled a moment to start up
sleep 3

# Bring the Tailscale interface up
# This uses the auth key from your environment variables
/app/tailscale up --authkey=${TS_AUTHKEY} --accept-routes

# Start your actual application
# Replace '/app/my-app' with your actual app's command if different
echo "Starting main application..."
/app/my-app

# Keep the script running
wait $!
