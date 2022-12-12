# How to use

Before you use this make sure you have docker installed on your devices.

## Installation

### Mac & Windows

Install Docker CE for Mac and Windows (http://docker.com)

### Ubuntu

To install Docker CE follow the instructions given here:

https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/

#### Install docker-compose

```sh
    sudo apt install docker-compose
```

### Running docker-compose file

First copy the local.env.example and changes the env file

```sh
cp local.env.example local.env
```

then run the script using bash
```sh
bash run-docker.sh
```

### Stopping docker-compose
```sh
   docker-compose down
```

fyi just simple docker-compose.yaml configuration for localhost so feel free to contribute 👋
