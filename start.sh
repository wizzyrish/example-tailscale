#!/bin/bash

# Start tailscaled in the background
/app/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &

# Bring the Tailscale interface up
# This uses the auth key from your environment variables
# You can add --hostname=my-cool-app or other flags here
/app/tailscale up --authkey=${TS_AUTHKEY} --accept-routes

# Start your actual application
# Replace '/app/my-app' with your actual app's command if different
echo "Starting main application..."
/app/my-app

# Keep the script running
wait $!
