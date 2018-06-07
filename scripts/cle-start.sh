#!/bin/bash

export NRP_USER=faichele

echo "============================"
echo "    CLE entrypoint start    "
echo "============================"
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

echo "PYTHONPATH before sourcing setup bash scripts: $PYTHONPATH"
source /opt/ros/kinetic/setup.bash
source $HBP/user-scripts/nrp_variables
source $HBP/user-scripts/nrp_functions
source $HBP/user-scripts/nrp_aliases
echo "PYTHONPATH after sourcing setup bash scripts: $PYTHONPATH"

export GAZEBO_MASTER_URI=http://nrp-cle:11345

sleep 1

echo "Starting nginx..."
$HOME/.local/etc/init.d/nginx restart
echo "Started nginx."
sleep 1

export PYTHONPATH=$PYTHONPATH:$HOME/.opt/platform_venv/lib/python2.7/site-packages
echo "Starting ROSCLESimulationFactory..."
echo "PYTHONPATH: $PYTHONPATH"
PYTHONPATH=$PYTHONPATH:$HOME/.opt/platform_venv/lib/python2.7/site-packages python $HBP/ExDBackend/hbp_nrp_cleserver/hbp_nrp_cleserver/server/ROSCLESimulationFactory.py &
echo "Started ROSCLESimulationFactory."
sleep 1
echo "Starting uwsgi... HBP directory: $HBP"
PYTHONPATH=$PYTHONPATH:$HOME/.opt/platform_venv/lib/python2.7/site-packages uwsgi --ini $HOME/.local/etc/nginx/uwsgi-nrp.ini &
echo "Started uwsgi."

exec tail -f /dev/null
