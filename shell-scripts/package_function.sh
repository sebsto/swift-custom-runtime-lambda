#!/bin/sh +x

#
# Run this script from your project directory 
#

FUNCTION_NAME=SwiftLambdaHelloWorld

PROJECT_DIR=$(basename `pwd`)
LAMBDA_DIR=lambda
BUILD_DIR=.build
EXECUTABLE_NAME=HelloSwiftLambda # must be the same as in Package.swift
LAMBDA_ZIP=function.zip
IAM_ROLE_NAME="lambda_basic_execution2"

BUILD_TYPE=debug #debug or release

which docker > /dev/null
if [ ! $? ];
then
    echo "Docker is not installed, to use this script please install docker first"
    exit -1
fi

echo "Building"
# TODO - should install zlib in a custom docker image
docker run  -it --rm  -v $(pwd):/$PROJECT_DIR --env PROJECT_DIR=/$PROJECT_DIR swift /bin/bash -c "apt-get update && apt-get install -y zlib1g-dev && cd $PROJECT_DIR && swift build -c $BUILD_TYPE"

echo "Packaging"
mkdir $LAMBDA_DIR 2>/dev/null # create the directory, silently fails when it already exists
cp ./shell-scripts/bootstrap $LAMBDA_DIR
cp $BUILD_DIR/x86_64-unknown-linux/$BUILD_TYPE/$EXECUTABLE_NAME $LAMBDA_DIR

rm $LAMBDA_ZIP 2>/dev/null
pushd $LAMBDA_DIR >/dev/null 
zip $LAMBDA_ZIP bootstrap  $EXECUTABLE_NAME
popd >/dev/null

# create lambda function if it does not exist 
echo 'Deploying to AWS (creating IAM role and function as needed)'
IAM_ROLE_ARN=$(aws iam list-roles --query "Roles[? RoleName == '$IAM_ROLE_NAME'].Arn" --output text)
if [ -z "$IAM_ROLE_ARN" ];
then
    echo "IAM Role $IAM_ROLE_NAME does not exist, let create it"
    aws iam create-role --role-name $IAM_ROLE_NAME --description "Allows Lambda functions to call AWS services on your behalf." --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["sts:AssumeRole"],"Principal":{"Service":["lambda.amazonaws.com"]}}]}' 
    aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" 
    IAM_ROLE_ARN=$(aws iam list-roles --query "Roles[? RoleName == '$IAM_ROLE_NAME'].Arn" --output text)
fi 

FUNCTION_EXIST=$(aws lambda list-functions --query "length(Functions[?FunctionName == '$FUNCTION_NAME'])")
if [ $FUNCTION_EXIST -eq "0" ];
then
    echo "Function $FUNCTION_NAME does not exist, let's create it"
    LAMBDA_LAYER_ARN=$(cat lambda_layer_arn.txt)
    aws lambda create-function --function-name $FUNCTION_NAME  --runtime provided --handler $EXECUTABLE_NAME --role "$IAM_ROLE_ARN" --zip-file fileb://$LAMBDA_DIR/$LAMBDA_ZIP --layers $LAMBDA_LAYER_ARN || {
        # sometime, function creation fails 
        # (An error occurred (InvalidParameterValueException) when calling the CreateFunction operation: The role defined for the function cannot be assumed by Lambda.)
        # in this case, just wait a bit and retry 
        echo "Function creation failed with exit code $?, let's retry in 10 secs"
        sleep 10
        aws lambda create-function --function-name $FUNCTION_NAME  --runtime provided --handler $EXECUTABLE_NAME --role "$IAM_ROLE_ARN" --zip-file fileb://$LAMBDA_DIR/$LAMBDA_ZIP --layers $LAMBDA_LAYER_ARN
    } 
else
    # update lamda code
    echo "Uploading new code to $FUNCTION_NAME"
    aws lambda update-function-code --function-name $FUNCTION_NAME --zip-file fileb://$LAMBDA_DIR/$LAMBDA_ZIP
fi

echo "Done"