#!/bin/sh +x

#
# Run this script from your project directory 
#

PROJECT_DIR=$(basename `pwd`)
LAMBDA_DIR=lambda
LAMBDA_LAYER_ZIP=lambda-swift-layer.zip

which docker > /dev/null
if [  ! $? ];
then
    echo "Docker is not installed, to use this script please install docker first"
    exit -1
fi

# Create the packaging directory if it does not exist 
if [ ! -d $LAMBDA_DIR/lib ];
then
   echo "Creating layer's lib directory"
   mkdir -p $LAMBDA_DIR/lib
fi

# Pull the latest version of the official swift container
# https://hub.docker.com/_/swift/
docker pull swift:4.2.1

# Copy all shared libs required to run a swift executable to swift-layer/lib directory 
echo "Copying runtime shared libs"
docker run  -it --rm  -v $(pwd):/$PROJECT_DIR --env PROJECT_DIR=/$PROJECT_DIR swift /bin/bash -c "/$PROJECT_DIR/shell-scripts/extract_libs.sh"

# Package the lib as ZIP file for Lambda Layer
echo "Packaging the layer"
pushd $LAMBDA_DIR >/dev/null
rm $LAMBDA_LAYER_ZIP 2>/dev/null
zip -r $LAMBDA_LAYER_ZIP lib/ >/dev/null
popd >/dev/null

echo "Uploading Lambda layer from $LAMBDA_DIR/$LAMBDA_LAYER_ZIP"
LAMBDA_LAYER_ARN=$(aws lambda publish-layer-version --layer-name swift-4-2-1 --description "Swift runtime shared libraries" --zip-file fileb://./lambda/lambda-swift-layer.zip --output text --query LayerVersionArn)
echo $LAMBDA_LAYER_ARN >lambda_layer_arn.txt
echo "Done, ARN = $LAMBDA_LAYER_ARN"