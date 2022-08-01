#!/bin/bash

set -e
sudo /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
