from nvidia/cuda:11.2.1-base-ubuntu20.04
run apt-get update && DEBIAN_FRONTEND="noninteractive" TZ="America/New_York" apt-get install -y\
  xserver-xorg-dev\
  libegl1-mesa-dev\
  libgl1-mesa-dev\
  libgbm-dev\
  mesa-common-dev\
  libgles2-mesa\
  libwayland-egl1-mesa\
  nvidia-driver-440\
  && rm -rf /var/lib/apt/lists/*
run echo "default-server = unix:/run/user/1000/pulse/native" >> /etc/pulse/client.conf
