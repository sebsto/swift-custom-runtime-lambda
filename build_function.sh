#!/bin/sh +x

#
# Run this script from your project directory 
#

PROJECT_DIR=$(basename `pwd`)
LAMBDA_DIR=lambda
LAMBDA_LAYER_ZIP=lambda-swift-layer.zip
BUILD_DIR=/$PROJECT_DIR/.build

which docker > /dev/null
if [  ! $? ];
then
    echo "Docker is not installed, to use this script please install docker first"
    exit -1
fi

# Pull the latest version of the official swift containers
docker pull swift:4.2.1

# Compile project in container 
echo "Compiling swift code in the container"
rm -rf $BUILD_DIR/*
docker run  -it --rm  -v $(pwd):/$PROJECT_DIR --env PROJECT_DIR=/$PROJECT_DIR swift /bin/bash -c "cd $PROJECT_DIR && swift build"
echo "Done"