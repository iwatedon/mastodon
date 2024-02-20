#!/bin/bash

set -e
set -o pipefail

ips=$(curl -fsS https://www.dan.me.uk/torlist/?exit | sed '/^#/ !s/^/deny  /g; s/$/;/g')
filename=/etc/nginx/conf.d/deny-tor-ips.conf
cat <<EOF | sudo tee $filename > /dev/null 2>&1
$ips
EOF
sudo systemctl restart nginx.service
