#!/bin/sh +x

#
# Run this script from your project directory 
#

PROJECT_DIR=$(basename `pwd`)
LAMBDA_DIR=lambda
BUILD_DIR=.build
EXECUTABLE_NAME=$PROJECT_DIR
LAMBDA_ZIP=function.zip

echo "Building"
docker run  -it --rm  -v $(pwd):/$PROJECT_DIR --env PROJECT_DIR=/$PROJECT_DIR swift:4.2.1 /bin/bash -c "cd hello && swift build"

echo "Packaging"
cp bootstrap $LAMBDA_DIR
cp $BUILD_DIR/x86_64-unknown-linux/debug/$EXECUTABLE_NAME $LAMBDA_DIR

rm $LAMBDA_ZIP 2>/dev/null
pushd $LAMBDA_DIR >/dev/null 
zip $LAMBDA_ZIP bootstrap  $EXECUTABLE_NAME
popd >/dev/null

# create lambda function if it does not exist 

# update lamda code
echo "Uploading"
aws lambda update-function-code --function-name swifttest --zip-file fileb://./lambda/function.zip

echo "Done"