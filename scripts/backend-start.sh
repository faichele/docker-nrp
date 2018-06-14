#!/bin/bash

echo "========================"
echo "Backend Entrypoint begin"
echo "========================"

echo "NRP installation directory: $NRP_INSTALL_DIR"
echo "NRP base directory: $HBP"
echo "NRP user: $NRP_USER"

source /opt/ros/kinetic/setup.bash

echo "Starting roscore..."
nohup roscore &
echo "Started roscore."
sleep 1

echo "Starting web_video_server..."
nohup rosrun web_video_server web_video_server _port:=8081 &
echo "Started web_video_server."

exec tail -f /dev/null
