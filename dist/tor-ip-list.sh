#!/bin/bash

curl https://check.torproject.org/exit-addresses | grep 'ExitAddress' | awk '{ print $2 }' | sort -V | uniq | sed '/^#/ !s/^/deny  /g; s/$/;/g' | sudo tee /etc/nginx/conf.d/deny-tor-ips.conf
