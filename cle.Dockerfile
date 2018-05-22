FROM zyklio-nrp-backend-dev

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

RUN echo "NRP_USER: ${NRP_USER}"
RUN echo "NRP_NUM_PROCESSES: ${NRP_NUM_PROCESSES}"

# Install node, nginx, and uwsgi
user root
RUN /bin/bash -c "apt-get -y install nodejs npm libgts-dev libjansson-dev imagemagick \
    		  nginx-extras lua-cjson uwsgi-plugin-python && \
		  mkdir -p -v  /var/lib/nginx/body /var/lib/nginx/fastcgi /var/lib/nginx/proxy /var/lib/nginx/scgi /var/lib/nginx/uwsgi && \
		  chown www-data.root /var/lib/nginx/body /var/lib/nginx/fastcgi /var/lib/nginx/proxy /var/lib/nginx/scgi /var/lib/nginx/uwsgi && \
                  chmod 700 /var/lib/nginx/body /var/lib/nginx/fastcgi /var/lib/nginx/proxy /var/lib/nginx/scgi /var/lib/nginx/uwsgi"

RUN /bin/bash -c "chown -R ${NRP_USER}:${NRP_USER} ${HOME} -R"

USER ${NRP_USER}

RUN mkdir -p /home/${NRP_USER}/.gazebo/models

RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.0/install.sh | bash

USER root
RUN ln -s /usr/bin/nodejs /usr/bin/node

USER ${NRP_USER}
RUN /bin/bash -c "mkdir $HOME/nginx && touch $HOME/nginx/nginx.pid"

ENV TERM linux
ENV ENVIRONMENT dev
ENV PKG_CONFIG_PATH ${NRP_INSTALL_DIR}/lib/pkgconfig:/opt/ros/${NRP_ROS_VERSION}/lib/pkgconfig:${PKG_CONFIG_PATH}

WORKDIR ${NRP_SOURCE_DIR}/gzweb
RUN /bin/bash -c "source $HOME/.nvm/nvm.sh && nvm install 0.10 \
    && nvm install 8 \
    && nvm alias default 8 \
    && nvm use default \
    && npm install -g bower \
    && npm install && cd gz3d/utils && npm install"

ENV GAZEBO_MODEL_PATH /home/${NRP_USER}/.gazebo/models

WORKDIR ${NRP_SOURCE_DIR}/gzweb
RUN /bin/bash -c "source $HOME/.nvm/nvm.sh && \ 
                  nvm use 0.10 && ./deploy-gzbridge-nrp.sh && nvm use default"

WORKDIR ${NRP_SOURCE_DIR}/user-scripts
# RUN /bin/bash -c "source $HOME/.nvm/nvm.sh && \
#    ./configure_nrp"

# configure_nrp script in a nutshell
RUN /bin/bash -c "mkdir -p -v ${HOME}/.local/etc/nginx ${HOME}/.local/etc/init.d ${HOME}/.local/etc/default ${HOME}/nginx ${HOME}/.local/var/log/nginx ${HOME}/.local/etc/nginx/lua ${HOME}/.local/etc/nginx/conf.d ${HOME}/.opt/bbp/nrp-services"

RUN /bin/bash -c "source ./repos.txt && \
		  ./purge && \
                  echo \"Copying user_makefile to python repos\" && \
                  cp -fv ${HBP}/user-scripts/config_files/user_makefile ${HBP}/BrainSimulation && \
                  cp -fv ${HBP}/user-scripts/config_files/user_makefile ${HBP}/ExperimentControl && \
                  cp -fv ${HBP}/user-scripts/config_files/user_makefile ${HBP}/VirtualCoach && \
                  cp -fv ${HBP}/user-scripts/config_files/user_makefile ${HBP}/CLE && \
                  cp -fv ${HBP}/user-scripts/config_files/user_makefile ${HBP}/ExDBackend"

RUN /bin/bash -c "echo \"Copying Frontend config.json file\" && \
                  ln -s ${HBP}/user-scripts/config_files/ExDFrontend/config.json.local ${HBP}/ExDFrontend/app/config.json.local && \
                  cp ${HBP}/ExDFrontend/app/config.json.local ${HBP}/ExDFrontend/app/config.json && \
                  sed -e 's/<username>/'\"${USER}\"'/' -i $HBP/ExDFrontend/app/config.json"

RUN /bin/bash -c "mkdir -p -v ${HOME}/.opt/bbp/nrp-services"
RUN ls -lR ${HOME}/.opt
RUN /bin/bash -c "echo \"Copying start/stop scripts for gzserver and gzbridge\" && \
                  cp -av ${HBP}/user-scripts/nrp-services/* ${HOME}/.opt/bbp/nrp-services"
                  
RUN /bin/bash -c "chmod u+x ${HOME}/.opt/bbp/nrp-services/gzbridge && \
                  chmod u+x ${HOME}/.opt/bbp/nrp-services/gzserver"

WORKDIR ${NRP_SOURCE_DIR}/gzweb
RUN python ${NRP_SOURCE_DIR}/user-scripts/generatelowrespbr.py
                  
RUN /bin/bash -c "echo \"Copying CLE config.ini file\" && \
                  ln -s ${HBP}/user-scripts/config_files/CLE/config.ini.sample ${HBP}/CLE/hbp_nrp_cle/hbp_nrp_cle/config.ini.sample && \
                  cp ${HBP}/CLE/hbp_nrp_cle/hbp_nrp_cle/config.ini.sample ${HBP}/CLE/hbp_nrp_cle/hbp_nrp_cle/config.ini"

RUN /bin/bash -c "echo \"Copying hbp-flask-restful config files.\" && \
                  ln -s ${HBP}/user-scripts/config_files/hbp-flask-restful-swagger-master/config.json.sample ${HBP}/ExDBackend/hbp-flask-restful-swagger-master/flask_restful_swagger/static/config.json.sample && \
                  cp ${HBP}/ExDBackend/hbp-flask-restful-swagger-master/flask_restful_swagger/static/config.json.sample ${HBP}/ExDBackend/hbp-flask-restful-swagger-master/flask_restful_swagger/static/config.json"

RUN /bin/bash -c "echo \"Copying Proxy config files.\" && \
                  ln -s ${HBP}/user-scripts/config_files/nrpBackendProxy/config.json.sample.local ${HBP}/nrpBackendProxy/config.json.sample.local"
                  
RUN /bin/bash -c "source ${HOME}/.bashrc && \
                  source ${HOME}/.nvm/nvm.sh && \
                  nvm use 8 && \
                  nvm alias default 8 && \
                  printf \"Switched to node v8. Please reopen all your shells and restart the server.\\n\""

RUN /bin/bash -c "mkdir -p -v ${HOME}/.local/etc/nginx ${HOME}/.local/etc/init.d ${HOME}/.local/etc/default ${HOME}/nginx ${HOME}/.local/var/log/nginx ${HOME}/.local/etc/nginx/lua ${HOME}/.local/etc/nginx/conf.d"
RUN /bin/bash -c "echo \"Copying Nginx config files\" && \
                  cp -arv /etc/nginx/* ${HOME}/.local/etc/nginx/ && \
                  cp -v /etc/init.d/nginx $HOME/.local/etc/init.d/nginx && \
                  sed -e 's/ \\/etc\\// \\/home\\/'"${NRP_USER}"'\\/.local\\/etc\\//' -i /home/${NRP_USER}/.local/etc/init.d/nginx && \
                  echo 'DAEMON_OPTS=\"-c ${HOME}/.local/etc/nginx/nginx.conf -p ${HOME}/.local/etc/nginx\"' >  $HOME/.local/etc/default/nginx"

RUN cp -v ${HBP}/user-scripts/config_files/nginx/nginx.conf ${HOME}/.local/etc/nginx/nginx.conf
RUN /bin/bash -c "sed -e 's/<username>/'\"${NRP_USER}\"'/g' -i ${HOME}/.local/etc/nginx/nginx.conf"
RUN /bin/bash -c "sed -e 's/<groupname>/'\"${NRP_USER}\"'/g' -i $HOME/.local/etc/nginx/nginx.conf"
                  
RUN cp -v ${HBP}/user-scripts/config_files/nginx/conf.d/* ${HOME}/.local/etc/nginx/conf.d
RUN /bin/bash -c "sed -e 's|<HBP>|'\"${HBP}\"'|' -i ${HOME}/.local/etc/nginx/conf.d/nrp-services.conf"
RUN /bin/bash -c "sed -e 's/<username>/'\"${NRP_USER}\"'/' -i ${HOME}/.local/etc/nginx/conf.d/nrp-services.conf"
RUN /bin/bash -c "sed -e 's|<HBP>|'\"${HBP}\"'|' -i ${HOME}/.local/etc/nginx/conf.d/frontend.conf"

RUN cp -vr ${HBP}/user-scripts/config_files/nginx/lua/* ${HOME}/.local/etc/nginx/lua

RUN /bin/bash -c "echo \"Copying uwsgi config file\" && \
                  cp ${HBP}/user-scripts/config_files/nginx/uwsgi-nrp.ini ${HOME}/.local/etc/nginx/uwsgi-nrp.ini"

RUN /bin/bash -c "echo \"Copying VirtualCoach config.json file\" && \
                  cp -v ${HBP}/user-scripts/config_files/VirtualCoach/config.json ${HBP}/VirtualCoach/hbp_nrp_virtual_coach/hbp_nrp_virtual_coach/config.json"

RUN /bin/bash -c "echo \"Copying VirtualCoach bbpclient\" && \
                  mkdir -pv ${HOME}/.opt/platform_venv/lib/python2.7/site-packages/ &&\
                  cp -afv ${HBP}/user-scripts/config_files/VirtualCoach/platform_venv/* ${HOME}/.opt/platform_venv/lib/python2.7/site-packages/"
                                    
# Backend components
# ExperimentControl 
WORKDIR ${NRP_SOURCE_DIR}/ExperimentControl
RUN export VIRTUAL_ENV=$VIRTUAL_ENV && make devinstall

# CLE 
WORKDIR ${NRP_SOURCE_DIR}/CLE
RUN export VIRTUAL_ENV=$VIRTUAL_ENV && make devinstall

# BrainSimulation
WORKDIR ${NRP_SOURCE_DIR}/BrainSimulation
RUN export VIRTUAL_ENV=$VIRTUAL_ENV && make devinstall

RUN /bin/bash -c "echo \"Generating schema parsers for ExDBackend\" && \
                  source $HOME/.opt/platform_venv/bin/activate && \
                  pyxbgen -u ${HBP}/Experiments/bibi_configuration.xsd -m bibi_api_gen && \
                  pyxbgen -u ${HBP}/Experiments/ExDConfFile.xsd -m exp_conf_api_gen && \
                  pyxbgen -u ${HBP}/Models/environment_model_configuration.xsd -m environment_conf_api_gen && \
                  pyxbgen -u ${HBP}/Models/robot_model_configuration.xsd -m robot_conf_api_gen && \
                  mv -v bibi_api_gen.py $HBP/ExDBackend/hbp_nrp_commons/hbp_nrp_commons/generated && \
                  mv exp_conf_api_gen.py ${HBP}/ExDBackend/hbp_nrp_commons/hbp_nrp_commons/generated && \
                  mv _sc.py ${HBP}/ExDBackend/hbp_nrp_commons/hbp_nrp_commons/generated && \
                  mv robot_conf_api_gen.py ${HBP}/ExDBackend/hbp_nrp_commons/hbp_nrp_commons/generated && \
                  mv environment_conf_api_gen.py ${HBP}/ExDBackend/hbp_nrp_commons/hbp_nrp_commons/generated && \
                  deactivate"

user root
RUN apt-get -y install python-dev python-h5py python-lxml \
    autogen \
    zlib1g-dev python-opencv \
    ruby libtar-dev libprotoc-dev protobuf-compiler \
    libtinyxml2-dev \
    libblas-dev \
    qt4-default libqtwebkit4 libqtwebkit-dev libfreeimage-dev libtbb-dev

# ExDBackend
USER ${NRP_USER}
WORKDIR ${NRP_SOURCE_DIR}/ExDBackend
RUN export VIRTUAL_ENV=$VIRTUAL_ENV && make devinstall

# VirtualCoach
WORKDIR ${NRP_SOURCE_DIR}/VirtualCoach
RUN export VIRTUAL_ENV=$VIRTUAL_ENV && make devinstall
 
USER ${NRP_USER}
CMD tail -f /dev/null
