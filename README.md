# AWS Lambda Custom Runtime for Swift

This library demonstrates how to use the [Swift programming language](https://swift.org) to develop [AWS Lambda functions](https://aws.amazon.com/lambda).

This demo is based on the newly released (November 2018) [Lambda Layers](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html) and [Lambda Custom Runtime](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html).
The former allows to share common code and libraries across multiple Lambda functions.  The latter allows you to upload code written in any programming language by providing an API to fetch Lambda events and to communicate success and errors with the Lambda service.

This demo project's objectives are twofold :
- to provide a Swift implementation of the [AWS Lambda Runtime API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html), to let Swift Lambda function developers to focus on their code and not the underlying runtime, and
- to provide a runtime environment for Swift applications to run on Amazon Linux, the host operating system for Lambda runtime.

## High Level Steps (TL;DR)

Lambda functions run inside containers on top of Amazon Linux (see [re:Invent 2018's Deep Dive into Lambda](https://www.youtube.com/watch?v=QdzV04T_kec) to learn more about it).

On the other side, Apple and the community [are providing binaries](https://swift.org/download/#releases) for MacOS and Ubuntu Linux only.

Here are the high level steps to create a runtime environment on Amazon Linux.

We'll use Docker to develop and test on our local machine, with the [official Docker Swift](https://hub.docker.com/_/swift/) image and [the official Amazon Linux](https://hub.docker.com/_/amazonlinux/) image.

Your Lambda function source code and required binary files will be stored on our laptop, we'll use [docker volumes](https://docs.docker.com/storage/volumes/) to mount our project directory to the Swift and Amazon Linux containers.

1. Copy from the [official Docker Swift](https://hub.docker.com/_/swift/) image all runtime's shared libraries required to run a swift application, and package them in order to use them on Amazon Linux.  
This is a one time operation.  I am using [this manually crafted list of shared libraries][swift-libs] that works for me, some additional ones might be required depending on your code.

2. Create a Lambda Layer containing all the runtime shared libraries. This is a one time operation. 

[1] and [2] are done with ``./shell-scripts/package_layer.sh``

3. Create your Lambda function like the one below.

```swift
import LambdaRuntime

func handler(context: Context, event: LambdaEvent) throws -> LambdaResponse {
    return [
        "result": event["key1"] ?? "unknown key : key1"
    ]
}

try LambdaRuntime(handler).run()
```

This function leverages a ``LambdaRuntime`` class to interact with Lambda Runtime API.  This class is provided as part of this project, as well as the required Lambda's bootstrap script.

4. Compile your swift code to Linux binaries.  We'll use the [official Docker Swift](https://hub.docker.com/_/swift/) image to do that.

[4] is done with ``./shell-scripts/build_function.sh``

5. Test inside the Amazon Linux docker container

[5] is done with ``./shell-scripts/run_function.sh``

6. Deploy to AWS Lambda and enjoy !

[6] is done with ``./shell-scripts/package_function.sh``

## Step by Step Instructions 

### Prerequisites

I am using 2 docker containers for this project.  The first one is [the official Swift container](https://hub.docker.com/_/swift/), it will provide us with **a build environment** for our Swift source code.  The second one is the official Amazon Linux container, it will provide us **a runtime environment** to test our code before to upload it to AWS Lambda.

```bash
docker pull swift:5.1.2
docker pull amazonlinux:2018.03
```

(To install Docker, follow [the instructions on their web site](https://www.docker.com/products/docker-desktop))

You'll also need to have [AWS CLI](https://aws.amazon.com/cli/) [installed](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) and [configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) to access Lambda on your AWS Account.

### Getting Started

In order for you to deploy your first Swift Lambda function, follow these steps.

1. Clone this repository
```bash
git clone https://github.com/sebsto/swift-custom-runtime-lambda
cd swift-custom-runtime-lambda 
```

The project is made of a couple of shell scripts and three directories.  ``lambda-runtime`` contains the Swift source code to interact with the Lambda Runtime API.  You should not modify this code.  ``lambda-function`` contains the source code of your Lambda function.  finally, the ``shell-scripts`` directory contains helper scripts to build, package and test your code.  These scripts will create a ``lambda`` directory containing all the binaries artifacts that will be deployed to AWS Lambda.

![directory layout](/images/dir_layout.png?raw=true)

2. Create a Lambda Layer, containing all runtime Linux shared libraries.

```bash
./shell-scripts/package_layer.sh
````

This script starts a Swift docker container and runs [a shell script](https://github.com/sebsto/swift-custom-runtime-lambda/blob/master/shell-scripts/extract_libs.sh) to extract a [list of runtime libraries][swift-libs] that will be needed on Amazon Linux to run your Swift binary.  The libraries are copied to ``lambda/libs`` directory.  It will create a zip ``lambda/-lambda-swift-layer.zip`` and will create a Lambda layer on your AWS account, in the default region.

The ARN of the newly created Layer version is stored in a file called ``lambda_layer_arn.txt``

3. Write your own function code.  The sample provided in this repo just reads the incoming event and create a simple JSON based response.

```swift
import LambdaRuntime

func handler(context: Context, event: LambdaEvent) throws -> LambdaResponse {
    return [
        "result": event["key1"] ?? "unknown key : key1"
    ]
}

try LambdaRuntime(handler).run()
```

The ``LambdaRuntime`` class is the implementation of the Lambda Runtime API, it will take your function ``handler`` as argument and will start the event loop. It will also initialise the ``Context`` and ``LambdaEvent`` objects.  The ``LambdaEvent`` is just a type alias to a Dictionary ``[String:Any]``.

4. Compile and package your binaries.

```bash
./shell-scripts/package_function.sh
```

This script starts a Linux Swift container and runs the ``swift build`` command, the build will produce binaries in the ``.build`` directory.  It will then copy the binary to the ``lambda`` directory and create a zip file and upload it to Lambda. The first time, it will create the Lambda function and an IAM execution role.  Subsequent calls will just update the code part of the Lambda function.

5. Test locally on Amazon Linux

```bash
./shell-scripts/run_function.sh
```

This script starts an Amazon Linux container and execute the ``bootstrap`` script to launch the Swift Lambda Runtime.  This runtime will, in turn, call your function code.  Output and debugging information will be displayed on the standard output.  
If everything goes well, you should see a line like the below :

```
[INFO] [LambdaRuntimeAPI.swift:158 invocationSuccess(awsRequestId:response:)] SUCCESS : Request-Id = request-id-123
["result": "value1"]
```

## What's next?

Congrats if you're still reading and if you successfully managed to create your own function.  You are now ready to test it on Lambda.

### Testing on Lambda

1. Connect to the AWS Lambda console

![lambda console](/images/lambda_console.png)

2. Click on "Functions" on the left, then on the name of the function that has been created just before (``SwiftLambdaHelloWorld`` if you did not change the default)

![lambda function](/images/lambda_function.png) 

3. Open the "Select a test event" drop down and click on "Configure test events" to prepare a dummy payload.

    - Enter a simple JSON with ``"key1"`` as key name and any value.
    - Enter a name for your test event, such as ``testevent``
    - Click "Save" at the bottom of the screen 

![test event](/images/test_event.png)

4. Click on "TEST" to invoke your Swift based Lambda function.  When everything works well, you should see a green screen looking like this :

![test result](/images/test_result.png)

If you receive an error message, do not throw away your laptop immediately.  Usually, reading the error message will give you a clue of what went wrong.

### Developing on XCode

Should you want to use Apple's XCode as IDE, you can create an XCode project from the [Swift package definition](https://github.com/sebsto/swift-custom-runtime-lambda/blob/master/Package.swift).

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
- Split the `package_function.sh` code in two scripts, one to `package` and one to `deploy`
- Create two distinct Swift projects, one for the runtime and one for your Lambda function
- Package the Swift RunTime as a shared library and in a distinct Lambda layer for reuse across multiple functions.
- Allow the handler to make an HTTPS call.  Swift's implementation relies on ``libgnutls`` which expects to find its root certificates in ``/etc/ssl/certs/ca-certificates.crt`` directory.  That directory is absent on Amazon Linux.  **Currently calls to HTTPS endpoint will fail with an error** : ``error setting certificate verify locations:\n CAfile: /etc/ssl/certs/ca-certificates.crt\n CApath: /etc/ssl/certs``

## References 

Thank you for the pionering work made by these folks by first attempting to run Swift binaries inside Lambda function : 

- Matthew Burke, Capital One : https://medium.com/capital-one-tech/serverless-computing-with-swift-f515ff052919

- Justin Sanders : https://medium.com/@gigq/using-swift-in-aws-lambda-6e2a67a27e03

- Claus Höfele, https://medium.com/@claushoefele/serverless-swift-2e8dce589b68

- Kohki Miki, Cookpad : https://github.com/giginet/aws-lambda-swift-runtime

- Toni Sutter : https://github.com/tonisuter/aws-lambda-swift

[swift-libs]: https://github.com/sebsto/swift-custom-runtime-lambda/blob/master/shell-scripts/swift-linux-libs.txt