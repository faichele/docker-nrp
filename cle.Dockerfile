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

LABEL com.nvidia.volumes.needed="nvidia_driver"
ENV PATH /usr/local/nvidia/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64:${LD_LIBRARY_PATH}

# Install node, nginx, and uwsgi
user root
RUN /bin/bash -c "apt-get -y install nodejs npm libgts-dev libjansson-dev imagemagick \
    		  nginx-extras lua-cjson uwsgi-plugin-python && \
		  mkdir -p -v  /var/lib/nginx/body /var/lib/nginx/fastcgi /var/lib/nginx/proxy /var/lib/nginx/scgi /var/lib/nginx/uwsgi && \
		  chown www-data.root /var/lib/nginx/body /var/lib/nginx/fastcgi /var/lib/nginx/proxy /var/lib/nginx/scgi /var/lib/nginx/uwsgi && \
                  chmod 700 /var/lib/nginx/body /var/lib/nginx/fastcgi /var/lib/nginx/proxy /var/lib/nginx/scgi /var/lib/nginx/uwsgi && \
                  ln -s /usr/bin/nodejs /usr/bin/node && \
		  chown ${NRP_USER}.${NRP_USER} ${HOME}/nrp -R"

# RUN /bin/bash -c "chown -R ${NRP_USER}:${NRP_USER} ${HOME} -R"

USER ${NRP_USER}
RUN /bin/bash -c "mkdir -p /home/${NRP_USER}/.gazebo/models && \
                  curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.0/install.sh | bash"

USER ${NRP_USER}
RUN /bin/bash -c "mkdir $HOME/nginx && touch $HOME/nginx/nginx.pid"

ENV TERM=linux \
    ENVIRONMENT=dev \
    PKG_CONFIG_PATH=${NRP_INSTALL_DIR}/lib/pkgconfig:/opt/ros/${NRP_ROS_VERSION}/lib/pkgconfig:${PKG_CONFIG_PATH} \
    GAZEBO_MODEL_PATH=/home/${NRP_USER}/.gazebo/models

# Backend components
WORKDIR ${NRP_SOURCE_DIR}/user-scripts
COPY ./config/repos.txt ${NRP_SOURCE_DIR}/user-scripts/repos.txt
RUN /bin/bash -c "source ${NRP_SOURCE_DIR}/user-scripts/repos.txt && \
                  echo \"Copying user_makefile to python repos\" && \
                  cp -fv ${HBP}/user-scripts/config_files/user_makefile ${HBP}/BrainSimulation && \
                  cp -fv ${HBP}/user-scripts/config_files/user_makefile ${HBP}/ExperimentControl && \
                  cp -fv ${HBP}/user-scripts/config_files/user_makefile ${HBP}/VirtualCoach && \
                  cp -fv ${HBP}/user-scripts/config_files/user_makefile ${HBP}/CLE && \
                  cp -fv ${HBP}/user-scripts/config_files/user_makefile ${HBP}/ExDBackend"

# ExperimentControl 
WORKDIR ${NRP_SOURCE_DIR}/ExperimentControl
RUN export VIRTUAL_ENV=$VIRTUAL_ENV && make devinstall

# BrainSimulation
WORKDIR ${NRP_SOURCE_DIR}/BrainSimulation
RUN export VIRTUAL_ENV=$VIRTUAL_ENV && make devinstall

# CLE 
WORKDIR ${NRP_SOURCE_DIR}/CLE
RUN export VIRTUAL_ENV=$VIRTUAL_ENV && make devinstall

# What is this needed for?
RUN /bin/bash -c "$HBP/CLE/ubuntu_fix_cv2.sh"

RUN /bin/bash -c "echo \"Generating schema parsers for ExDBackend\" && \
                  source $HOME/.opt/platform_venv/bin/activate && \
		  ls ${HBP}/Experiments && \
                  ls ${HBP}/Models && \
                  if [ -f ${HBP}/Experiments/bibi_configuration.xsd ]; then  pyxbgen -u ${HBP}/Experiments/bibi_configuration.xsd -m bibi_api_gen; fi && \
                  if [ -f ${HBP}/Experiments/ExDConfFile.xsd ]; then pyxbgen -u ${HBP}/Experiments/ExDConfFile.xsd -m exp_conf_api_gen; fi && \
                  if [ -f ${HBP}/Models/environment_model_configuration.xsd ]; then pyxbgen -u ${HBP}/Models/environment_model_configuration.xsd -m environment_conf_api_gen; fi && \
                  if [ -f ${HBP}/Models/robot_model_configuration.xsd ]; then pyxbgen -u ${HBP}/Models/robot_model_configuration.xsd -m robot_conf_api_gen; fi && \
                  mv -v bibi_api_gen.py $HBP/ExDBackend/hbp_nrp_commons/hbp_nrp_commons/generated && \
                  mv -v exp_conf_api_gen.py ${HBP}/ExDBackend/hbp_nrp_commons/hbp_nrp_commons/generated && \
                  mv -v _sc.py ${HBP}/ExDBackend/hbp_nrp_commons/hbp_nrp_commons/generated && \
                  mv -v robot_conf_api_gen.py ${HBP}/ExDBackend/hbp_nrp_commons/hbp_nrp_commons/generated && \
                  mv -v environment_conf_api_gen.py ${HBP}/ExDBackend/hbp_nrp_commons/hbp_nrp_commons/generated && \
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

# nginx configuration for this Docker setup
COPY ./config/nginx/frontend.conf /home/${NRP_USER}/.local/etc/nginx/conf.d/frontend.conf

USER root
RUN /bin/bash -c "chown ${NRP_USER}:${NRP_USER} /home/${NRP_USER}/.local -R"

# configure_nrp script in a nutshell
WORKDIR ${NRP_SOURCE_DIR}/user-scripts

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
RUN /bin/bash -c "echo \"Copying start/stop scripts for gzserver and gzbridge\" && \
                  cp -av ${HBP}/user-scripts/nrp-services/* ${HOME}/.opt/bbp/nrp-services"

RUN /bin/bash -c "chmod u+x ${HOME}/.opt/bbp/nrp-services/gzbridge && \
                  chmod u+x ${HOME}/.opt/bbp/nrp-services/gzserver"

USER root
# Frontend components - nvm
RUN /bin/bash -c "source $HOME/.nvm/nvm.sh \
    && nvm install 8 \
    && nvm install 0.10.48 \
    && nvm alias default 8 \
    && nvm use default \
    && npm install -g bower \
    && nvm use 0.10.48 \
    && npm install -g bower \
    && nvm use default \
    && chown ${NRP_USER}:${NRP_USER} $HOME/.nvm $HOME/.npm $HOME/.config $HOME/.local -R"

USER ${NRP_USER}

WORKDIR ${NRP_SOURCE_DIR}/gzweb
RUN /bin/bash -c "source $HOME/.nvm/nvm.sh && nvm use 0.10 && \
	          ${NRP_SOURCE_DIR}/gzweb/deploy-gzbridge-nrp.sh && \
    		  npm dedupe && \
    		  git checkout -- package.json && \
    		  npm install --no-save && \
    		  cd gz3d/utils && \
    		  npm dedupe && \
    		  git checkout -- package.json && \
    		  npm install --no-save && \
    		  cd $HBP && \
    		  virtualenv lower_res && \
    		  source lower_res/bin/activate && \
    		  pip install pillow==4.3.0 && \
    		  python $HBP/user-scripts/generatelowrespbr.py && \
    		  deactivate && \
    	          rm -rf lower_res"
WORKDIR ${NRP_SOURCE_DIR}/Models
RUN /bin/bash -c "source ${NRP_SOURCE_DIR}/user-scripts/nrp_variables && \
                  source ${NRP_SOURCE_DIR}/user-scripts/nrp_functions && \
		  ${NRP_SOURCE_DIR}/Models/create-symlinks.sh && \
		  echo ${NRP_VIRTUAL_ENV} && \
    		  source $HOME/.opt/platform_venv/bin/activate && \ 
    		  pip install -r $HBP/Experiments/template_requirements.txt && \
   		  deactivate"

RUN /bin/bash -c "echo \"Copying CLE config.ini file\" && \
                  ln -s ${HBP}/user-scripts/config_files/CLE/config.ini.sample ${HBP}/CLE/hbp_nrp_cle/hbp_nrp_cle/config.ini.sample && \
                  cp ${HBP}/CLE/hbp_nrp_cle/hbp_nrp_cle/config.ini.sample ${HBP}/CLE/hbp_nrp_cle/hbp_nrp_cle/config.ini"

RUN /bin/bash -c "echo \"Copying hbp-flask-restful config files.\" && \
                  ln -s ${HBP}/user-scripts/config_files/hbp-flask-restful-swagger-master/config.json.sample ${HBP}/ExDBackend/hbp-flask-restful-swagger-master/flask_restful_swagger/static/config.json.sample && \
                  cp ${HBP}/ExDBackend/hbp-flask-restful-swagger-master/flask_restful_swagger/static/config.json.sample ${HBP}/ExDBackend/hbp-flask-restful-swagger-master/flask_restful_swagger/static/config.json"

RUN /bin/bash -c "echo \"Copying Proxy config files.\" && \
                  ln -s ${HBP}/user-scripts/config_files/nrpBackendProxy/config.json.sample.local ${HBP}/nrpBackendProxy/config.json.sample.local"

# RUN /bin/bash -c "source ${HOME}/.bashrc && \
#                  source ${HOME}/.nvm/nvm.sh && \
#                  nvm use 8 && \
#                  nvm alias default 8 && \
#                  printf \"Switched to node v8. Please reopen all your shells and restart the server.\\n\""

RUN /bin/bash -c "mkdir -p -v ${HOME}/.local/etc/nginx ${HOME}/.local/etc/init.d ${HOME}/.local/etc/default ${HOME}/nginx ${HOME}/.local/var/log/nginx ${HOME}/.local/etc/nginx/lua ${HOME}/.local/etc/nginx/conf.d"
RUN /bin/bash -c "echo \"Copying Nginx config files\" && \
                  cp -arv /etc/nginx/* ${HOME}/.local/etc/nginx/ && \
                  cp -v /etc/init.d/nginx $HOME/.local/etc/init.d/nginx && \
                  sed -e 's/ \\/etc\\// \\/home\\/'"${NRP_USER}"'\\/.local\\/etc\\//' -i /home/${NRP_USER}/.local/etc/init.d/nginx && \
                  echo 'DAEMON_OPTS=\"-c ${HOME}/.local/etc/nginx/nginx.conf -p ${HOME}/.local/etc/nginx\"' >  $HOME/.local/etc/default/nginx"

RUN cp -v ${HBP}/user-scripts/config_files/nginx/nginx.conf ${HOME}/.local/etc/nginx/nginx.conf
RUN /bin/bash -c "sed -e 's/<username>/'\"${NRP_USER}\"'/g' -i ${HOME}/.local/etc/nginx/nginx.conf && \
                  sed -e 's/<groupname>/'\"${NRP_USER}\"'/g' -i $HOME/.local/etc/nginx/nginx.conf"

RUN cp -v ${HBP}/user-scripts/config_files/nginx/conf.d/* ${HOME}/.local/etc/nginx/conf.d
RUN /bin/bash -c "sed -e 's|<HBP>|'\"${HBP}\"'|' -i ${HOME}/.local/etc/nginx/conf.d/nrp-services.conf && \
                  sed -e 's/<username>/'\"${NRP_USER}\"'/' -i ${HOME}/.local/etc/nginx/conf.d/nrp-services.conf && \
                  sed -e 's|<HBP>|'\"${HBP}\"'|' -i ${HOME}/.local/etc/nginx/conf.d/frontend.conf"

RUN cp -vr ${HBP}/user-scripts/config_files/nginx/lua/* ${HOME}/.local/etc/nginx/lua

RUN /bin/bash -c "echo \"Copying uwsgi config file\" && \
                  cp ${HBP}/user-scripts/config_files/nginx/uwsgi-nrp.ini ${HOME}/.local/etc/nginx/uwsgi-nrp.ini"

RUN /bin/bash -c "echo \"Copying VirtualCoach config.json file\" && \
                  cp -v ${HBP}/user-scripts/config_files/VirtualCoach/config.json ${HBP}/VirtualCoach/hbp_nrp_virtual_coach/hbp_nrp_virtual_coach/config.json"

RUN /bin/bash -c "echo \"Copying VirtualCoach bbpclient\" && \
                  mkdir -pv ${HOME}/.opt/platform_venv/lib/python2.7/site-packages/ &&\
                  cp -afv ${HBP}/user-scripts/config_files/VirtualCoach/platform_venv/* ${HOME}/.opt/platform_venv/lib/python2.7/site-packages/"

USER root
COPY ./scripts/cle-start.sh /usr/local/bin/cle-start.sh
RUN /bin/bash -c "chmod +x /usr/local/bin/cle-start.sh && \
                  apt-get -y install ruby-compass && \
                  gem install compass"

USER ${NRP_USER}

WORKDIR /home/${NRP_USER}
CMD tail -f /dev/null
