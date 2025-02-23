FROM debian:latest
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    vim \
    git \
    curl \
    wget \
    unzip \
    lsb-release \
    gnupg \
    software-properties-common \
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update && apt-get install -y terraform

RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

RUN useradd -m -s /bin/bash bielik \
    && echo "bielik ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

ARG NB_USER=bielik
ARG NB_UID=1000
ARG NB_GID=100

RUN echo "eval \$(dircolors -b)" >> /home/bielik/.bashrc \
    && echo "PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '" >> /home/bielik/.bashrc \
    && echo "alias ls='ls --color=auto'" >> /home/bielik/.bashrc \
    && echo "alias grep='grep --color=auto'" >> /home/bielik/.bashrc \
    && echo "alias diff='diff --color=auto'" >> /home/bielik/.bashrc \
    && chown bielik:bielik /home/bielik/.bashrc

USER bielik
WORKDIR /home/bielik

CMD ["bash"]






