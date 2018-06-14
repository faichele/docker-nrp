FROM nvidia/opengl:1.0-glvnd-runtime-ubuntu16.04
# FROM ubuntu:xenial
# FROM mythical.alpenland.local:8102/fabian/docker-qtcreator

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

RUN userdel user || true
RUN groupdel  user || true
RUN groupdel  ${NRP_USER} || true
RUN groupadd -g 1000 ${NRP_USER} || true

RUN userdel ${NRP_USER} || true
RUN useradd -s /bin/bash -u 1000 -g 1000 ${NRP_USER} || true

RUN mkdir -p ${HOME} || true
RUN mkdir -p ${NRP_SOURCE_DIR} || true
RUN mkdir -p ${NRP_INSTALL_DIR} || true
RUN mkdir -p ${NRP_SOURCE_DIR}/../platform_venv || true

COPY ./config/bashrc $HOME/.bashrc
RUN chown -R ${NRP_USER}.${NRP_USER} ${HOME}

COPY sources.list /etc/apt/sources.list

# Install prerequisites
RUN rm -rf /var/cache/apt/archives/* && apt-get update
RUN apt-get install -y sudo \
    autoconf automake \
    build-essential cmake \
    gfortran \
    git \
    ipython \
    libgsl0-dev libhdf5-dev liblapack-dev libblas-dev libltdl7-dev libpq-dev libqt4-dev libtool libxslt1-dev \
    python-all-dev python-matplotlib python-numpy python-pip python-scipy python-virtualenv \
    libncurses5-dev \
    libreadline6-dev \
    ssh net-tools \
    curl libcurl3 php-curl \
    cython python-mpi4py \
    nano xvfb libxv1 \
    software-properties-common python-software-properties \
    libffi-dev \
    pkg-config \
    bison byacc libtool-bin \
    nano vim logrotate \
    iputils-ping

WORKDIR ${HOME}/downloads
RUN wget --no-check-certificate downloads.sourceforge.net/project/virtualgl/2.5.1/virtualgl_2.5.1_amd64.deb \
    && dpkg -i virtualgl_2.5.1_amd64.deb \
    && sudo rm -rf virtualgl_2.5.1_amd64.deb

# add ros
RUN apt-get update \
    && apt-get install --no-install-recommends -y wget\
    software-properties-common python-software-properties \
    python-rosdep python-rosinstall python-vcstools \
    locales

# setup environment
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8

# setup keys
RUN apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 421C365BD9FF1F717815A3895523BAEEB01FA116

# setup sources.list
RUN echo "deb http://packages.ros.org/ros/ubuntu xenial main" > /etc/apt/sources.list.d/ros-latest.list

# install bootstrap tools
RUN apt-get update && apt-get install --no-install-recommends -y \
    python-rosdep \
    python-rosinstall \
    python-vcstools

# bootstrap rosdep
RUN rosdep init \
    && rosdep update

# install ros packages
RUN apt-get update && apt-get install -y \
    ros-${NRP_ROS_VERSION}-ros-core

RUN apt-get update && apt-get install -y \
    ros-${NRP_ROS_VERSION}-ros-base

RUN apt-get update && \
    apt-get install -y --fix-missing ros-${NRP_ROS_VERSION}-control-toolbox \
    ros-${NRP_ROS_VERSION}-controller-manager \
    ros-${NRP_ROS_VERSION}-transmission-interface \
    ros-${NRP_ROS_VERSION}-joint-limits-interface \
    ros-${NRP_ROS_VERSION}-rosauth \
    ros-${NRP_ROS_VERSION}-smach-ros \
    ros-${NRP_ROS_VERSION}-rosauth \
    ros-${NRP_ROS_VERSION}-web-video-server

# Clone repos
WORKDIR ${NRP_SOURCE_DIR}
RUN git clone https://bitbucket.org/hbpneurorobotics/user-scripts

WORKDIR ${NRP_SOURCE_DIR}/user-scripts
RUN /bin/bash -c "echo \"Cloning all repositories\" && ./clone-all-repos"

# COPY ./autogen.sh ${NRP_SOURCE_DIR}/mvapich2/autogen.sh

# Install Gazebo prerequisites
RUN apt-get remove -y *sdformat*
RUN apt-get remove -y --purge gazebo6* \
    && wget -O - http://packages.osrfoundation.org/gazebo.key | apt-key add - \
    && apt-add-repository "deb http://packages.osrfoundation.org/gazebo/ubuntu xenial main"

RUN apt-get update && \
    apt-get install --no-install-recommends -y wget \
    libignition-math2-dev \
    libignition-transport-dev \
    libignition-transport0-dev \
    libboost-all-dev libtinyxml-dev libtinyxml2-dev ruby protobuf-compiler\
    && pip install psutil

RUN apt-get install -y libogre-1.9.0v5 libogre-1.9-dev

# Install GazeboRosPackages prerequisites
RUN apt-get install -y \
    ros-${NRP_ROS_VERSION}-sensor-msgs \
    ros-${NRP_ROS_VERSION}-angles \
    ros-${NRP_ROS_VERSION}-tf \
    ros-${NRP_ROS_VERSION}-image-transport \
    ros-${NRP_ROS_VERSION}-cv-bridge \
    ros-${NRP_ROS_VERSION}-control-toolbox \
    ros-${NRP_ROS_VERSION}-controller-manager \
    ros-${NRP_ROS_VERSION}-transmission-interface \
    ros-${NRP_ROS_VERSION}-joint-limits-interface \
    ros-${NRP_ROS_VERSION}-polled-camera \
    ros-${NRP_ROS_VERSION}-diagnostic-updater \
    ros-${NRP_ROS_VERSION}-rosbridge-server \
    ros-${NRP_ROS_VERSION}-camera-info-manager \
    ros-${NRP_ROS_VERSION}-xacro

# Compile and install sdformat
RUN mkdir -p ${NRP_SOURCE_DIR}/sdformat/build
WORKDIR ${NRP_SOURCE_DIR}/sdformat/build
RUN cmake -DCMAKE_INSTALL_PREFIX=${NRP_INSTALL_DIR} ${NRP_SOURCE_DIR}/sdformat
RUN make -j4
RUN make install

# Compile and install bulletphysics
RUN mkdir -p ${NRP_SOURCE_DIR}/bulletphysics/build
WORKDIR ${NRP_SOURCE_DIR}/bulletphysics/build
RUN cmake -DCMAKE_INSTALL_PREFIX=${NRP_INSTALL_DIR} ${NRP_SOURCE_DIR}/bulletphysics
RUN make -j4
RUN make install

# Compile and install SimBody
RUN mkdir -p ${NRP_SOURCE_DIR}/simbody/build
WORKDIR ${NRP_SOURCE_DIR}/simbody/build
RUN cmake -DCMAKE_INSTALL_PREFIX=${NRP_INSTALL_DIR} ${NRP_SOURCE_DIR}/simbody
RUN make -j4
RUN make install

# Compile and install OpenSim
RUN mkdir -p ${NRP_SOURCE_DIR}/opensim/build
WORKDIR ${NRP_SOURCE_DIR}/opensim/build
RUN cmake -DCMAKE_INSTALL_PREFIX=${NRP_INSTALL_DIR} ${NRP_SOURCE_DIR}/opensim
RUN make -j4
RUN make install

# Compile and install Gazebo
RUN mkdir -p ${NRP_SOURCE_DIR}/gazebo/build
WORKDIR ${NRP_SOURCE_DIR}/gazebo/build
RUN apt-get update && apt-get install -y libogre-1.9-dev xsltproc libqtwebkit-dev libfreeimage-dev libtar-dev libprotoc-dev libtbb-dev libcurl4-openssl-dev
RUN cmake -DCMAKE_INSTALL_PREFIX=${NRP_INSTALL_DIR} -DENABLE_TESTS_COMPILATION:BOOL=False ${NRP_SOURCE_DIR}/gazebo
RUN make -j4
RUN make install

# Compile and install mvapich2
WORKDIR ${NRP_SOURCE_DIR}/mvapich2
COPY ./files/mvapich2/autogen.sh ${NRP_SOURCE_DIR}/mvapich2/autogen.sh
RUN rm -f ./configure && sync
RUN ./autogen.sh && sync
RUN ./configure --prefix=${NRP_INSTALL_DIR} --with-device=ch3:nemesis
RUN make -j4
RUN make install

ENV PKG_CONFIG_PATH ${NRP_INSTALL_DIR}/lib/pkgconfig:${NRP_INSTALL_DIR}/lib/x86_64-linux-gnu/pkgconfig:$PKG_CONFIG_PATH
ENV CMAKE_PREFIX_PATH ${NRP_INSTALL_DIR}/lib/x86_64-linux-gnu/cmake/gazebo:$CMAKE_PREFIX_PATH

RUN apt-get -y install python-dev python-h5py python-lxml \
    autogen \
    zlib1g-dev python-opencv \
    ruby libtar-dev libprotoc-dev protobuf-compiler \
    libtinyxml2-dev \
    libblas-dev \
    qt4-default libqtwebkit4 libqtwebkit-dev libfreeimage-dev libtbb-dev

ENV PKG_CONFIG_PATH ${NRP_INSTALL_DIR}/lib/pkgconfig:${NRP_INSTALL_DIR}/lib/x86_64-linux-gnu/pkgconfig:$PKG_CONFIG_PATH
ENV CMAKE_PREFIX_PATH ${NRP_INSTALL_DIR}/lib/x86_64-linux-gnu/cmake/gazebo:$CMAKE_PREFIX_PATH

ENV PATH ${NRP_SOURCE_DIR}/MUSIC:$PATH
# Install Music
WORKDIR ${NRP_SOURCE_DIR}/MUSIC
RUN apt-get install -y cython python-mpi4py \
    && ln -sf ${NRP_INSTALL_DIR}/bin/mpichversion mpich2version \
    && ./autogen.sh \
    && ./configure --prefix=${NRP_INSTALL_DIR} MPI_CXX=mpicxx\
    && make -j4 \
    && make install

# Install NEST
WORKDIR ${NRP_SOURCE_DIR}/nest-simulator
RUN virtualenv build_venv \
    && . build_venv/bin/activate \
    && pip install Cython==0.23.4 mpi4py==2.0.0 \
    && mkdir build && cd build \
    && cmake -DCMAKE_INSTALL_PREFIX:PATH=${NRP_INSTALL_DIR} -Dwith-gsl=ON -Dwith-mpi=ON -Dwith-music=ON .. \
    && make -j4 \
    && make install \
    && cd ../SpikingCerebellum/src/CerebellumModule \
    && mkdir build && cd build && cmake .. && make && make install \
    && cd ../../../../build/ && cmake -DCMAKE_INSTALL_PREFIX:PATH=${NRP_INSTALL_DIR} -Dwith-gsl=ON -Dwith-mpi=ON -Dwith-music=ON -Dexternal-modules=cerebellum .. \
    && make -j4 \
    && make install \
    && deactivate

# Install experiement specific libraries
# Install retina
RUN mkdir -p ${NRP_SOURCE_DIR}/retina/build
WORKDIR ${NRP_SOURCE_DIR}/retina/build
RUN qmake-qt4 ${NRP_SOURCE_DIR}/retina/retina.pro INSTALL_PREFIX=${NRP_SOURCE_DIR}/retina/build CONFIG+=release CONFIG+=nodisplay \
    && make -j4 \
    && make install

# Install nengo
RUN pip install nengo

# Install GazeboRosPackages
ENV CMAKE_PREFIX_PATH ${NRP_INSTALL_DIR}/lib/cmake/gazebo/:$CMAKE_PREFIX_PATH
WORKDIR ${NRP_SOURCE_DIR}/GazeboRosPackages
ENV LD_LIBRARY_PATH ${NRP_INSTALL_DIR}/lib:$LD_LIBRARY_PATH
ENV CMAKE_PREFIX_PATH ${NRP_INSTALL_DIR}/lib/cmake/gazebo:${NRP_INSTALL_DIR}/lib/cmake/sdformat:$CMAKE_PREFIX_PATH
RUN /bin/bash -c "source ${NRP_INSTALL_DIR}/share/gazebo/setup.sh \
    && source /opt/ros/${NRP_ROS_VERSION}/setup.bash \
    && catkin_make --make-args -j4"

USER root
COPY ./scripts/backend-start.sh /usr/local/bin/backend-start.sh
RUN chmod +x /usr/local/bin/backend-start.sh
COPY ./scripts/nrp_variables /etc/nrp/nrp_variables

RUN usermod -a -G sudo ${NRP_USER}

RUN chown ${NRP_USER}:${NRP_USER} /home/${NRP_USER}/.ros -R

WORKDIR /home/${NRP_USER}

USER ${NRP_USER}
CMD tail -f /dev/null
