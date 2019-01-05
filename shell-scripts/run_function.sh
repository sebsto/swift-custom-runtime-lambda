#!/bin/sh

PROJECT_DIR=$(basename `pwd`)
LAMBDA_DIR=lambda
BUILD_DIR=.build
EXECUTABLE_NAME=HelloSwiftLambda # must be the same as in Package.swift
LAMBDA_ZIP=function.zip

which docker > /dev/null
if [  ! $? ];
then
    echo "Docker is not installed, to use this script please install docker first"
    exit -1
fi

# Pull the latest version of the official swift containers
docker pull amazonlinux:2018.03

# Run the code in the Amazon Linux container
docker run  -it --rm  -v $(pwd):/$PROJECT_DIR -v $(pwd)/$LAMBDA_DIR/lib:/opt/lib --env _HANDLER=$EXECUTABLE_NAME --env LAMBDA_TASK_ROOT=/$PROJECT_DIR/$LAMBDA_DIR --env LAMBDA_EVENT="{\"key1\":\"value1\"}" amazonlinux:2018.03 /bin/bash -c "cd $PROJECT_DIR && ./$LAMBDA_DIR/bootstrap"