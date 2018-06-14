FROM zyklio-nrp-cle-dev

ARG NRP_USER
ARG NRP_NUM_PROCESSES
ARG ROS_MASTER_URI

#   Set enviroment to build from bitbucket
ENV NRP_INSTALL_MODE=user \
    HOME=/home/${NRP_USER} \
    NRP_ROS_VERSION=kinetic \
    NRP_SOURCE_DIR=/home/${NRP_USER}/nrp/src \
    NRP_INSTALL_DIR=/home/${NRP_USER}/.local \
    HBP=${NRP_SOURCE_DIR} \
    ROS_MASTER_URI=${ROS_MASTER_URI}

#   Set environment vars
ENV C_INCLUDE_PATH=${NRP_INSTALL_DIR}/include:$C_INCLUDE_PATH \
    CPLUS_INCLUDE_PATH=${NRP_INSTALL_DIR}/include:$CPLUS_INCLUDE_PATH \
    CPATH=${NRP_INSTALL_DIR}/include:$CPATH \
    LD_LIBRARY_PATH=${NRP_INSTALL_DIR}/lib:$LD_LIBRARY_PATH \
    PATH=${NRP_INSTALL_DIR}/bin:$PATH \
    VIRTUAL_ENV=${HOME}/.opt/platform_venv

USER ${NRP_USER}
# brainvisualizer
# WORKDIR ${NRP_SOURCE_DIR}/brainvisualizer
RUN /bin/bash -c "cd ${NRP_SOURCE_DIR}/brainvisualizer && \
                  rm -rf node_modules && source $HOME/.nvm/nvm.sh && nvm use 8 && npm install"

# ExDFrontend
# WORKDIR ${NRP_SOURCE_DIR}/ExDFrontend
RUN /bin/bash -c "cd ${NRP_SOURCE_DIR}/ExDFrontend && \
                  rm -rf node_modules && source $HOME/.nvm/nvm.sh && nvm use 8 && npm install && \
                  npm install -g grunt && \
                  grunt build"

# nrpBackendProxy
# WORKDIR ${NRP_SOURCE_DIR}/nrpBackendProxy
RUN /bin/bash -c "cd ${NRP_SOURCE_DIR}/nrpBackendProxy && \
                  source $HOME/.nvm/nvm.sh && nvm use 8 && npm install"

# SlurmClusterMonitor
# WORKDIR ${NRP_SOURCE_DIR}/SlurmClusterMonitor
RUN /bin/bash -c "cd ${NRP_SOURCE_DIR}/SlurmClusterMonitor && \
                  source $HOME/.nvm/nvm.sh && nvm use 8 && npm install"

# Setup local storage database
# RUN /bin/bash -c "echo \"Setting up local storage database\" && \
#                  source $HOME/.nvm/nvm.sh && nvm use 8 && \
#                  chmod +x ${HBP}/user-scripts/configure_storage_database && \
#                  ${HBP}/user-scripts/configure_storage_database"
                  
# RUN /bin/bash -c "echo \"Setting configuration files to default mode (offline mode)\" && \
#                   $HBP/user-scripts/running_mode \"2\" && \
#                   echo \"DONE\""

USER root

COPY ./scripts/frontend-start.sh /usr/local/bin/frontend-start.sh
RUN /bin/bash -c "chown ${NRP_USER}:${NRP_USER} ${HOME}/.local/etc -R && \
                  chmod +x /usr/local/bin/frontend-start.sh && \
		  mkdir -p /home/${NRP_USER}/.opt/nrpStorage && \
		  chown ${NRP_USER}:${NRP_USER} /home/${NRP_USER}/.opt -R"

USER ${NRP_USER}
# Call configure_nrp last?
WORKDIR ${NRP_SOURCE_DIR}/user-scripts
RUN /bin/bash -c "source ./nrp_variables && source ./nrp_functions && configure_nrp && \
                  sed -i \"s/http:\/\/localhost/http:\/\/nrp-cle/g\" ${HBP}/ExDFrontend/app/config.json ${HBP}/nrpBackendProxy/config.json && \
                  sed -i \"s/ws:\/\/localhost/ws:\/\/nrp-cle/g\" ${HBP}/ExDFrontend/app/config.json ${HBP}/nrpBackendProxy/config.json"

CMD tail -f /dev/null
