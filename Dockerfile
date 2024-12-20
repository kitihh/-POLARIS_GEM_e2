# syntax=docker/dockerfile:1

# Use Ubuntu 20.04 as the base image
FROM ubuntu:20.04

# Setiing build arguments
ARG BUILDKIT_INLINE_CACHE=1
ARG USER=ros
ARG UID=1000
ARG GID=1000
ARG ROS_DISTRO=noetic
ARG WORKSPACE_ROOT=/home/ros/workspace
ARG DEBIAN_FRONTEND=noninteractive
ARG REPO_URL=https://github.com/kitihh/POLARIS_GEM_e2
ARG REPO_BRANCH=DEV-Assignment-131224

# Setting package versions
ARG CURL_VERSION="7.68.0-1ubuntu2.25"
ARG GIT_VERSION="1:2.25.1-1ubuntu3.13"
ARG BUILD_ESSENTIAL_VERSION="12.8ubuntu1.1"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Setting labels for metadata
LABEL maintainer="Kirill Tihhonov" \
      version="1.0.0" \
      description="Polaris GEM e2 Simulator containerization and test" \
      org.opencontainers.image.source="https://github.com/kitihh/POLARIS_GEM_e2" \
      org.opencontainers.image.licenses="MIT"

# Setting timezone
ENV TZ=UTC \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Combine RUN commands and use build cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y \
    curl=${CURL_VERSION} \
    git=${GIT_VERSION} \
    build-essential=${BUILD_ESSENTIAL_VERSION} \
    gnupg2 \
    lsb-release \
    sudo \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Creating non root user
RUN groupadd -g ${GID} ${USER} && \
    useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USER} && \
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER} && \
    chmod 0440 /etc/sudoers.d/${USER}

# Add ROS repository and install ROS packages in a single layer
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list' && \
    curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add - && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    ros-${ROS_DISTRO}-desktop-full \
    python3-rosdep \
    python3-rosinstall \
    python3-rosinstall-generator \
    python3-wstool \
    python3-catkin-tools \
    ros-${ROS_DISTRO}-ackermann-msgs \
    ros-${ROS_DISTRO}-geometry2 \
    ros-${ROS_DISTRO}-hector-gazebo \
    ros-${ROS_DISTRO}-hector-models \
    ros-${ROS_DISTRO}-jsk-rviz-plugins \
    ros-${ROS_DISTRO}-ros-control \
    ros-${ROS_DISTRO}-ros-controllers \
    ros-${ROS_DISTRO}-velodyne-simulator \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Initialize rosdep
RUN rosdep init && rosdep update

# Create workspace directory and clone repository
WORKDIR ${WORKSPACE_ROOT}/src
RUN git clone -b ${REPO_BRANCH} --depth 1 ${REPO_URL} 

# Build the workspace using multiple cores
WORKDIR ${WORKSPACE_ROOT}
RUN /bin/bash -c "source /opt/ros/noetic/setup.bash && catkin_make -j$(nproc)"

# Add source commands to bashrc
RUN echo "source /opt/ros/noetic/setup.bash" >> /root/.bashrc && \
    echo "source /root/gem_ws/devel/setup.bash" >> /root/.bashrc

# Set the working directory
WORKDIR ${WORKSPACE_ROOT}

# Default command
CMD ["/bin/bash"]