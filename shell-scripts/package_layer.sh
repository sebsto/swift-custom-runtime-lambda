#!/bin/sh +x

#
# Run this script from your project directory 
#

PROJECT_DIR=$(basename `pwd`)
LAMBDA_DIR=lambda
LAMBDA_LAYER_ZIP=lambda-swift-layer.zip
S3_BUCKET=public-sst

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
docker pull swift:5.1.2

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
aws s3 cp ./lambda/$LAMBDA_LAYER_ZIP s3://$S3_BUCKET/$LAMBDA_LAYER_ZIP
LAMBDA_LAYER_ARN=$(aws lambda publish-layer-version --layer-name swift-5-1-2 --description "Swift runtime shared libraries" --content S3Bucket=$S3_BUCKET,S3Key=$LAMBDA_LAYER_ZIP --output text --query LayerVersionArn)
echo $LAMBDA_LAYER_ARN >lambda_layer_arn.txt
echo "Done, ARN = $LAMBDA_LAYER_ARN"