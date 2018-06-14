#!/bin/bash

echo "================================="
echo "    Frontend entrypoint start    "
echo "================================="
if [ -z "$NRP_USER" ]; then
        echo "NRP_USER variable is not set, setting it now."
        export NRP_USER=`whoami`
else
        echo "NRP_USER is set to: $NRP_USER"
fi
echo "NRP_USER: $NRP_USER"
echo "Home directory: $HOME"
echo "NRP installation directory: $NRP_INSTALL_DIR"
echo "HBP directory: $HBP"

source /opt/ros/kinetic/setup.bash
source /etc/nrp/nrp_variables
source $HBP/user-scripts/nrp_functions
source $HBP/user-scripts/nrp_aliases

export GAZEBO_MASTER_URI=http://nrp-cle:11345

echo "Starting nrpBackendProxy..."
cd $HBP/nrpBackendProxy && node app.js &
echo "Started nrpBackendProxy."
sleep 5
echo "Starting rosbridge server..."
rosrun rosbridge_server rosbridge_websocket &
echo "Started rosbridge server."

sleep 5
echo "Starting ExDFrontend node.js server..."
cd $HBP/ExDFrontend && grunt serve &
echo "Started ExDFrontend node.js server."

exec tail -f /dev/null
