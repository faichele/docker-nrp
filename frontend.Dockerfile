FROM zyklio-nrp-cle-dev

ARG NRP_USER
ARG NRP_NUM_PROCESSES
ARG ROS_MASTER_URI

#   Set enviroment to build from bitbucket
ENV NRP_INSTALL_MODE user
ENV HOME /home/${NRP_USER}
ENV NRP_ROS_VERSION kinetic
ENV NRP_SOURCE_DIR /home/${NRP_USER}/nrp/src
ENV NRP_INSTALL_DIR /home/${NRP_USER}/.local
ENV HBP ${NRP_SOURCE_DIR}
ENV ROS_MASTER_URI ${ROS_MASTER_URI}

#   Set environment vars
ENV C_INCLUDE_PATH=${NRP_INSTALL_DIR}/include:$C_INCLUDE_PATH \
    CPLUS_INCLUDE_PATH=${NRP_INSTALL_DIR}/include:$CPLUS_INCLUDE_PATH \
    CPATH=${NRP_INSTALL_DIR}/include:$CPATH \
    LD_LIBRARY_PATH=${NRP_INSTALL_DIR}/lib:$LD_LIBRARY_PATH \
    PATH=${NRP_INSTALL_DIR}/bin:$PATH \
    VIRTUAL_ENV=${HOME}/.opt/platform_venv

USER root
RUN /bin/bash -c "apt-get -y install ruby-compass && \
                  gem install compass"

USER ${NRP_USER}

# Frontend components
RUN /bin/bash -c "source $HOME/.nvm/nvm.sh \
    && nvm install 8 \
    && nvm alias default 8 \
    && nvm use default"

# brainvisualizer
WORKDIR ${NRP_SOURCE_DIR}/brainvisualizer
RUN /bin/bash -c "rm -rf node_modules && source $HOME/.nvm/nvm.sh && nvm use 8 && npm install"

# ExDFrontend
WORKDIR ${NRP_SOURCE_DIR}/ExDFrontend
RUN /bin/bash -c "source $HOME/.nvm/nvm.sh && nvm use 8 && npm install && \
                  npm install -g grunt && \
                  grunt build"

# nrpBackendProxy
WORKDIR ${NRP_SOURCE_DIR}/nrpBackendProxy
RUN /bin/bash -c "source $HOME/.nvm/nvm.sh && nvm use 8 && npm install"

# SlurmClusterMonitor
WORKDIR ${NRP_SOURCE_DIR}/SlurmClusterMonitor
RUN /bin/bash -c "source $HOME/.nvm/nvm.sh && nvm use 8 && npm install"

# Setup local storage database
RUN /bin/bash -c "echo \"Setting up local storage database\" && \
                  source $HOME/.nvm/nvm.sh && nvm use 8 && \
                  chmod +x ${HBP}/user-scripts/configure_storage_database && \
                  ${HBP}/user-scripts/configure_storage_database"
                  
RUN /bin/bash -c "echo \"Setting configuration files to default mode (offline mode)\" && \
                  $HBP/user-scripts/running_mode \"2\" && \
                  echo \"DONE\""

# Finally, another chown to $NRP_USER}
USER root
RUN /bin/bash -c "chown -R ${NRP_USER}:${NRP_USER} ${HOME} -R"
 
RUN apt-get autoclean

USER ${NRP_USER}
CMD tail -f /dev/null
