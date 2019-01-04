#!/bin/sh

LAMBDA_DIR=$PROJECT_DIR/lambda

#
# This script is run inside the swift container to extract the runtime shared libraries
#

LIBS=$(cat $PROJECT_DIR/swift-linux-libs.txt)
for LIB in $LIBS
do 
  cp $LIB $LAMBDA_DIR/lib
done
