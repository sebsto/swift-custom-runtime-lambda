# AWS Lambda Custom Runtime for Swift

This library demonstrates how to use the [Swift programming language](https://swift.org) for [AWS Lambda functions](https://aws.amazon.com/lambda).

This demo is based on the newly released (November 2018) [Lambda Layers](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html) and [Lambda Custom Runtime](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html).
The former allows to share common code and libraries across multiple Lambda functions.  The latter allows you to upload code written in any programming language by providing your code with an API to fetch Lambda events and to communicate success and errors with the Lambda service.

## High Level Steps

Lambda functions run inside containers on top of Amazon Linux (see [re:Invent 2018's Deep Dive into Lambda](https://www.youtube.com/watch?v=QdzV04T_kec) to learn more about it), so our job is to provide a runtime environment for Swift applications on Amazon Linux.  Apple and the community [are providing binaries](https://swift.org/download/#releases) for MacOS and Ubuntu Linux only, here are the high level steps to create a runtime environment on Amazon Linux.

We'll use Docker to develop and test this on our local machine, with the [official Docker Swift](https://hub.docker.com/_/swift/) image and [the official Amazon Linux](https://hub.docker.com/_/amazonlinux/) image.

Source code and binary files will be stored on our laptop, we'll use [docker volumes](https://docs.docker.com/storage/volumes/) to mount our project directory to the Swift and Amazon Linux containers.

1. Copy from Swift docker image all runtime's shared libraries required to run a swift application, and package them to use them on Amazon Linux.
This is a one time operation.  I am using this manually crafted list of shared libraries that works for me, some additional ones might be required depending on your code.

2. Create a Lambda Layer containing all the runtime shared libraries. This is a one time operation.

3. Compile your swift code to Linux binaries.  We'll use the [official Docker Swift](https://hub.docker.com/_/swift/) image to do that.

4. Create a Lambda function containing a bootstrap script and your Swift binary 

```swift
import LambdaRuntime

func handler(context: Context, event: LambdaEvent) throws -> LambdaResponse {
    return [
        "result": event["key1"] ?? "unknown key : key1"
    ]
}

try LambdaRuntime(handler).run()
```

5. Test and enjoy :-)

## Prerequisites

I am using 2 docker containers for this project.  The first one is [the official Swift container](https://hub.docker.com/_/swift/), it will provide us with **a build environment** for our Swift source code.  The second one is the official Amazon Linux container, it will provide us **a runtime environment** to test our code before to upload it to AWS Lambda.

To install the two images, you can type in a terminal

```bash
docker pull swift:4.2.1
docker pull amazonlinux:2018.03
```

You'll also need to have [AWS CLI](https://aws.amazon.com/cli/) [installed](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) and [configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) to access Lambda on your AWS Account.

## Getting Started

In order for you to deploy your first Swift Lambda function, follow these steps.

1. Clone this repository
```bash
git clone https://....
cd swift-custom-runtime-lambda 
```

![directory layout](/images/dir_layout.png?raw=true)

The project is made of a couple of shell scripts and three directories.  ``lambda-runtime`` contains the Swift source code to interact with the Lambda Runtime API.  You should not modify this code.  ``lambda-function`` contains the source code of your Lambda function.  The shell scripts are helper to build, package and test your code, they are located in ``shell-scripts`` directory.  The scripts will create a ``lambda`` directory containing all the binaries artifacts that will be deployed to AWS Lambda.

2. Create a Lambda Layer, containing all runtime Linux shared libraries.

```bash
./shell-scripts/package_layer.sh
````

This script starts a Swift docker container and runs [a shell script](https://github.com/sebsto/swift-custom-runtime-lambda/blob/master/shell-scripts/extract_libs.sh) to extract a [list of runtime libraries](https://github.com/sebsto/swift-custom-runtime-lambda/blob/master/shell-scripts/swift-linux-libs.txt) that will be needed on Amazon Linux to run your Swift binary.  The libraries are copied to ``lambda/libs`` directory.  It will create a zip ``lambda/-lambda-swift-layer.zip`` and will create a layer on your AWS account, in the default region.

The ARN of the newly create Layer version is stored in a file called ``lambda_layer_arn.txt``

3. Write your own function code.  The sample provided in this repo just reads the incoming parameter and create a simple JSON based response.

```swift
import LambdaRuntime

func handler(context: Context, event: LambdaEvent) throws -> LambdaResponse {
    return [
        "result": event["key1"] ?? "unknown key : key1"
    ]
}

try LambdaRuntime(handler).run()
```

The ``LambdaRuntime`` class is the implementation of the Lambda Runtime API, it will take your function ``handler`` as argument and will start the event loop.

4. Compile and package your binaries.

```bash
./shell-scripts/package_function.sh
```

This script starts a Linux Swift container and runs the ``swift build`` command, the build will produce binaries in the ``.build`` directory.  It will then copy the binary to the ``lambda`` directory and create a zip file and uploads to Lambda.

5. Test locally on Amazon Linux

```bash
./shell-scripts/run_function.sh
```

This script starts an Amazon Linux container and execute the ``bootstrap`` script to launch the Swift Lambda Runtime.  This runtime will, in turn, call your function code.  Output and debugging information will be displayed on the standard output.

## What's next

Congrats if you're still reading and if you successfully managed to create your own function.  You are now ready to test it on Lambda.

### Testing on Lambda

TODO : include screenshots

1. Connect to the AWS Lambda console
2. Click on "Functions" on the left, then on the name of the function that has been created just before (``SwiftLambdaHelloWorld`` if you did not change the default)
3. Click on "TEST"... to prepare a dummy payload
4. Click on "TEST" and observe the results

### Developing on XCode

Should you want to use Apple's XCode as IDE, you can create an XCode project from the [Swift package definition](Thttps://github.com/sebsto/swift-custom-runtime-lambda/blob/master/Package.swift).

```bash
swift package generate-xcodeproj 
open HelloSwiftLambda.xcodeproj
```

## Ideas for contributions 

This is a demo project, please send your feedback through Twitter at [@sebsto](https://twitter.com/sebsto).

I will also happily accept your pull requests.

Here are some ideas :

- Squeeze any bugs I did not detect
- Add unit tests for the framework 
- Split the `package_function.sh` code in two scripts, one to `package` and one to `upload`
- Create two distinct Swift project, one for the runtime and one for your Lambda function
- Package the Swift RunTime as a shared library and in a distinct Lambda layer for reuse across multiple functions.