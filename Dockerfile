# syntax=docker/dockerfile:1

# Creating builder image
FROM ros:noetic-ros-base-focal AS builder

# Setting build arguments
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

# Creating non root user
RUN groupadd -g ${GID} ${USER} && \
    useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USER} && \
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER} && \
    chmod 0440 /etc/sudoers.d/${USER}

# Installing build dependencies with cache mounts
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    curl=${CURL_VERSION} \
    git=${GIT_VERSION} \
    build-essential=${BUILD_ESSENTIAL_VERSION} \
    ros-${ROS_DISTRO}-ackermann-msgs \
    ros-${ROS_DISTRO}-geometry2 \
    ros-${ROS_DISTRO}-hector-gazebo \
    ros-${ROS_DISTRO}-hector-models \
    ros-${ROS_DISTRO}-jsk-rviz-plugins \
    ros-${ROS_DISTRO}-ros-control \
    ros-${ROS_DISTRO}-ros-controllers \
    ros-${ROS_DISTRO}-velodyne-simulator \
    python3-rosdep \
    python3-rosinstall \
    python3-rosinstall-generator \
    python3-wstool \
    python3-catkin-tools \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Updating rosdep
RUN rosdep update

# Setting up and building workspace
WORKDIR ${WORKSPACE_ROOT}/src
RUN git clone -b ${REPO_BRANCH} --depth 1 ${REPO_URL} 
WORKDIR ${WORKSPACE_ROOT}
RUN bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && catkin_make -j$(nproc)"

# Runtime stage
FROM ros:noetic-ros-base-focal

# Setting build arguments
ARG USER=ros
ARG UID=1000
ARG GID=1000
ARG ROS_DISTRO=noetic
ARG WORKSPACE_ROOT=/home/ros/workspace
ARG DEBIAN_FRONTEND=noninteractive

# Setting environment variables
ENV ROS_ROOT=/opt/ros/${ROS_DISTRO}
ENV WORKSPACE_ROOT=${WORKSPACE_ROOT}
ENV PATH=${WORKSPACE_ROOT}/devel/bin:${PATH}
ENV PYTHONPATH=${WORKSPACE_ROOT}/devel/lib/python3/dist-packages:${PYTHONPATH}
ENV TZ=UTC

# Creating non root user
RUN groupadd -g ${GID} ${USER} && \
    useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USER} && \
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER} && \
    chmod 0440 /etc/sudoers.d/${USER}

# Installing runtime dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
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

# Coping artifacts from builder
COPY --from=builder --chown=${USER}:${USER} ${WORKSPACE_ROOT}/devel ${WORKSPACE_ROOT}/devel
COPY --from=builder --chown=${USER}:${USER} ${WORKSPACE_ROOT}/src ${WORKSPACE_ROOT}/src

# Creating and seting up volumes
RUN mkdir -p ${WORKSPACE_ROOT}/logs ${WORKSPACE_ROOT}/data && \
    chown -R ${USER}:${USER} ${WORKSPACE_ROOT}

VOLUME ["${WORKSPACE_ROOT}/logs", "${WORKSPACE_ROOT}/data"]

# Sourcing ROS environment in bashrc
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /home/${USER}/.bashrc && \
    echo "source ${WORKSPACE_ROOT}/devel/setup.bash" >> /home/${USER}/.bashrc

# Switch to non root user and start command
USER ${USER}
WORKDIR ${WORKSPACE_ROOT}
CMD ["bash"]