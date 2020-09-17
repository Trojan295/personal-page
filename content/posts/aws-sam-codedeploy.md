+++
date = "2020-09-17"
title = "Using AWS SAM and CodeDeploy to deploy serverless applications"
tags = [
    "aws",
    "serverless",
    "lambda",
    "devops",
    "codedeploy",
    "serverless application model",
    "sam",
]
categories = [
    "AWS",
]
+++

## AWS Serverless Application Model

I was recently preparing for my AWS DevOps Engineer exam and I wanted to give AWS Serverless Application Model a try. AWS Serverless Application Model is a framework to build and deploy serverless application on AWS using Lambda, API Gateway and DynamoDB.

Under the hood it is a AWS CloudFormation transform, which expands the CloudFormation syntax, by adding additional resources under the `AWS::Serverless` namespace. During the template provisioning those resources get expanded to basic CloudFormation resources.

The `sam` CLI has commands to build, test, package and deploy your serverless applications. It makes deploying serverless application much easier than packaging your application by yourself and using generic CloudFormation templates.

## Initialize the project

To initialize the project you use the `sam init` command. It will ask a few questions and prepare a boilerplate project.

{{< highlight shell "hl_lines=1 43" >}}
$ sam init 
Which template source would you like to use?
        1 - AWS Quick Start Templates
        2 - Custom Template Location
Choice: 1

Which runtime would you like to use?
        1 - nodejs12.x
        2 - python3.8
        3 - ruby2.7
        4 - go1.x
        5 - java11
        6 - dotnetcore3.1
        7 - nodejs10.x
        8 - python3.7
        9 - python3.6
        10 - python2.7
        11 - ruby2.5
        12 - java8.al2
        13 - java8
        14 - dotnetcore2.1
Runtime: 4

Project name [sam-app]: 

Cloning app templates from https://github.com/awslabs/aws-sam-cli-app-templates.git

AWS quick start application templates:
        1 - Hello World Example
        2 - Step Functions Sample App (Stock Trader)
Template selection: 1

-----------------------
Generating application:
-----------------------
Name: sam-app
Runtime: go1.x
Dependency Manager: mod
Application Template: hello-world
Output Directory: .

Next steps can be found in the README file at ./sam-app/README.md
$ tree
.
├── Makefile
├── README.md
├── hello-world
│   ├── go.mod
│   ├── main.go
│   └── main_test.go
└── template.yaml

1 directory, 6 files
{{< / highlight >}}

The project has a CloudFormation template in `template.yaml` and an example Lambda function handler in `hello-world/main.go`. You can notice the `Transform: AWS::Serverless-2016-10-31` field in the template, which means we are using AWS SAM:

{{< highlight yaml "linenos=table,hl_lines=2" >}}
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

[...]

Resources:
  HelloWorldFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: hello-world/
      Handler: hello-world
      Runtime: go1.x
      Tracing: Active
      Events:
        CatchAll:
          Type: Api
          Properties:
            Path: /hello
            Method: GET
      Environment:
        Variables:
          PARAM1: VALUE

[...]
{{</ highlight >}}
## Local development

Now to build the Lambda deployment packages run `sam build`.

{{< highlight bash >}}
$ sam build 
Building function 'HelloWorldFunction'
Running GoModulesBuilder:Build

Build Succeeded

Built Artifacts  : .aws-sam/build
Built Template   : .aws-sam/build/template.yaml

Commands you can use next
=========================
[*] Invoke Function: sam local invoke
[*] Deploy: sam deploy --guided
{{</ highlight >}}

A nice feature of SAM CLI is, that you can run the Lambda function locally or even deploy the whole API. For this you will need to have Docker installed.

{{< highlight bash >}}
$ sam local invoke HelloWorldFunction
Invoking hello-world (go1.x)
Failed to download a new amazon/aws-sam-cli-emulation-image-go1.x:rapid-1.1.0 image. Invoking with the already downloaded image.
Mounting /home/damian/Projects/sam-test/sam-app/.aws-sam/build/HelloWorldFunction as /var/task:ro,delegated inside runtime container
START RequestId: 861e0e67-1567-104f-55ba-5ee5b7c63eeb Version: $LATEST
END RequestId: 861e0e67-1567-104f-55ba-5ee5b7c63eeb
REPORT RequestId: 861e0e67-1567-104f-55ba-5ee5b7c63eeb  Init Duration: 49.63 ms Duration: 549.73 ms     Billed Duration: 600 ms Memory Size: 128 MB     Max Memory Used: 51 MB

{"statusCode":200,"headers":null,"multiValueHeaders":null,"body":"Hello, 178.43.131.97\n"}
{{</ highlight >}}

{{< highlight bash >}}
$ sam local start-api                
Mounting HelloWorldFunction at http://127.0.0.1:3000/hello [GET]
You can now browse to the above endpoints to invoke your functions. You do not need to restart/reload SAM CLI while working on your functions, changes will be reflected instantly/automatically. You only need to restart SAM CLI if you update your AWS SAM template
2020-09-17 17:54:42  * Running on http://127.0.0.1:3000/ (Press CTRL+C to quit)

# in other terminal
$ curl http://127.0.0.1:3000/hello                                      
Hello, 178.43.131.97
{{</ highlight >}}

## Deploy the application

To deploy Lambda functions you need package and upload your code to S3. AWS SAM will handle this for you, but it requires an additonal configuration file `samconfig.toml` to know what bucket it should use.

{{< highlight toml "linenos=table" >}}
# samconfig.toml
version = 0.1
[default]
[default.deploy]
[default.deploy.parameters]
stack_name = "sam-app"
s3_bucket = "aws-sam-cli-managed-default-samclisourcebucket-128t3n8a6nlhy"
s3_prefix = "sam-app"
region = "eu-west-1"
confirm_changeset = true
capabilities = "CAPABILITY_IAM"

{{< / highlight >}}

You can either provisiong the S3 bucket and create the `samconfig.toml` file manually or use the `--guided` flag in the `sam deploy` command, so SAM will create it for you.

What `sam deploy` does is:
1. Detect, which functions must be updated
2. Upload the CloudFormation template and Lambda deployment packages to S3
3. Generate the ChangeSet and deploy it

{{< highlight bash "hl_lines=1" >}}
$ sam deploy --guided

Configuring SAM deploy
======================

        Looking for samconfig.toml :  Not found

        Setting default arguments for 'sam deploy'
        =========================================
        Stack Name [sam-app]: 
        AWS Region [us-east-1]: eu-west-1
        #Shows you resources changes to be deployed and require a 'Y' to initiate deploy
        Confirm changes before deploy [y/N]: y
        #SAM needs permission to be able to create roles to connect to the resources in your template
        Allow SAM CLI IAM role creation [Y/n]: Y
        HelloWorldFunction may not have authorization defined, Is this okay? [y/N]: y
        Save arguments to samconfig.toml [Y/n]: 

        Looking for resources needed for deployment: Not found.
        Creating the required resources...
        Successfully created!

                Managed S3 bucket: aws-sam-cli-managed-default-samclisourcebucket-128t3n8a6nlhy
                A different default S3 bucket can be set in samconfig.toml

        Saved arguments to config file
        Running 'sam deploy' for future deployments will use the parameters saved above.
        The above parameters can be changed by modifying samconfig.toml
        Learn more about samconfig.toml syntax at 
        https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-config.html
Uploading to sam-app/4a708650ed51c1f21e152bcc6440cf00  1325 / 1325.0  (100.00%)

        Deploying with following values
        ===============================
        Stack name                 : sam-app
        Region                     : eu-west-1
        Confirm changeset          : True
        Deployment s3 bucket       : aws-sam-cli-managed-default-samclisourcebucket-128t3n8a6nlhy
        Capabilities               : ["CAPABILITY_IAM"]
        Parameter overrides        : {}

Initiating deployment
=====================
HelloWorldFunction may not have authorization defined.
Uploading to sam-app/cbc7be7eaba81f76b3cd7e012f847498.template  1155 / 1155.0  (100.00%)

Waiting for changeset to be created..

CloudFormation stack changeset
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Operation                                                         LogicalResourceId                                                 ResourceType                                                    
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+ Add                                                             HelloWorldFunctionCatchAllPermissionProd                          AWS::Lambda::Permission                                         
+ Add                                                             HelloWorldFunctionRole                                            AWS::IAM::Role                                                  
+ Add                                                             HelloWorldFunction                                                AWS::Lambda::Function                                           
+ Add                                                             ServerlessRestApiDeployment47fc2d5f9d                             AWS::ApiGateway::Deployment                                     
+ Add                                                             ServerlessRestApiProdStage                                        AWS::ApiGateway::Stage                                          
+ Add                                                             ServerlessRestApi                                                 AWS::ApiGateway::RestApi                                        
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Changeset created successfully. arn:aws:cloudformation:eu-west-1:146986152083:changeSet/samcli-deploy1600354796/6dc83be8-7e11-48c9-b6b0-8df847a66ac8


Previewing CloudFormation changeset before deployment
======================================================
Deploy this changeset? [y/N]: y

2020-09-17 17:00:07 - Waiting for stack create/update to complete

CloudFormation events from changeset
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
ResourceStatus                                   ResourceType                                     LogicalResourceId                                ResourceStatusReason                           
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE_IN_PROGRESS                               AWS::IAM::Role                                   HelloWorldFunctionRole                           -                                              
CREATE_IN_PROGRESS                               AWS::IAM::Role                                   HelloWorldFunctionRole                           Resource creation Initiated                    
CREATE_COMPLETE                                  AWS::IAM::Role                                   HelloWorldFunctionRole                           -                                              
CREATE_IN_PROGRESS                               AWS::Lambda::Function                            HelloWorldFunction                               -                                              
CREATE_COMPLETE                                  AWS::Lambda::Function                            HelloWorldFunction                               -                                              
CREATE_IN_PROGRESS                               AWS::Lambda::Function                            HelloWorldFunction                               Resource creation Initiated                    
CREATE_IN_PROGRESS                               AWS::ApiGateway::RestApi                         ServerlessRestApi                                -                                              
CREATE_COMPLETE                                  AWS::ApiGateway::RestApi                         ServerlessRestApi                                -                                              
CREATE_IN_PROGRESS                               AWS::ApiGateway::RestApi                         ServerlessRestApi                                Resource creation Initiated                    
CREATE_IN_PROGRESS                               AWS::ApiGateway::Deployment                      ServerlessRestApiDeployment47fc2d5f9d            -                                              
CREATE_IN_PROGRESS                               AWS::Lambda::Permission                          HelloWorldFunctionCatchAllPermissionProd         Resource creation Initiated                    
CREATE_IN_PROGRESS                               AWS::Lambda::Permission                          HelloWorldFunctionCatchAllPermissionProd         -                                              
CREATE_COMPLETE                                  AWS::ApiGateway::Deployment                      ServerlessRestApiDeployment47fc2d5f9d            -                                              
CREATE_IN_PROGRESS                               AWS::ApiGateway::Deployment                      ServerlessRestApiDeployment47fc2d5f9d            Resource creation Initiated                    
CREATE_IN_PROGRESS                               AWS::ApiGateway::Stage                           ServerlessRestApiProdStage                       -                                              
CREATE_IN_PROGRESS                               AWS::ApiGateway::Stage                           ServerlessRestApiProdStage                       Resource creation Initiated                    
CREATE_COMPLETE                                  AWS::ApiGateway::Stage                           ServerlessRestApiProdStage                       -                                              
CREATE_COMPLETE                                  AWS::Lambda::Permission                          HelloWorldFunctionCatchAllPermissionProd         -                                              
CREATE_COMPLETE                                  AWS::CloudFormation::Stack                       sam-app                                          -                                              
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

CloudFormation outputs from deployed stack
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Outputs                                                                                                                                                                                           
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Key                 HelloWorldFunctionIamRole                                                                                                                                                     
Description         Implicit IAM Role created for Hello World function                                                                                                                            
Value               arn:aws:iam::146986152083:role/sam-app-HelloWorldFunctionRole-URQ6NEJVAE9X                                                                                                    

Key                 HelloWorldAPI                                                                                                                                                                 
Description         API Gateway endpoint URL for Prod environment for First Function                                                                                                              
Value               https://xzv8lq1611.execute-api.eu-west-1.amazonaws.com/Prod/hello/                                                                                                            

Key                 HelloWorldFunction                                                                                                                                                            
Description         First Lambda Function ARN                                                                                                                                                     
Value               arn:aws:lambda:eu-west-1:146986152083:function:sam-app-HelloWorldFunction-DMK403RR7HEW                                                                                        
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Successfully created/updated stack - sam-app in eu-west-1
{{< / highlight >}}

{{< figure src="/images/aws-sam-codedeploy/aws_sam_cf_stacks.png" caption="CloudFormation stacks created by AWS SAM. `aws-sam-cli-managed-default` stack was created, because we used `--guided` and SAM provisioned the missing S3 bucket. `sam-app` stack is the actual serverless application" >}}

{{< figure src="/images/aws-sam-codedeploy/aws_sam_stack_resources.png" caption="Resources in the `sam-app` stack. The `AWS::Serverless::*` resources were transformed into other CloudFormation resources. SAM also implicitly created an API Gateway for us" >}}

## Enhance the template and add canary deployment

The nice thing in AWS SAM is, that it's just an extension of CloudFormation templates, so you can define other resources, export output values or reference values in other stacks. It also gives an option to define the deployment strategy for Lambda functions and set triggers for rollbacks. You can perform canary deployment on the AWS Lambda level by using Lambda aliases. Let's change the HelloWorld function, add `DeploymentPreference` and `AutoPublishAlias` parameters and define all CloudWatch alarm to rollback the deployment in case your function does not work during the CodeDeploy `AllowTraffic` phase.

{{< highlight yaml "linenos=table,hl_lines=3-22 31-35">}}
# template.yaml
[...]
Resources:
  HelloWorldServerErrorAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: HelloWorldServerErrorAlarm
      EvaluationPeriods: 1
      Metrics:
      - Id: m1
        MetricStat:
          Metric:
            Dimensions:
              - Name: FunctionName
                Value: !Ref HelloWorldFunction
            MetricName: Errors
            Namespace: AWS/Lambda
          Period: !!int 60
          Stat: Average
      ComparisonOperator: GreaterThanThreshold
      Threshold: 0.05
      TreatMissingData: notBreaching

  HelloWorldFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: hello-world/
      Handler: hello-world
      Runtime: go1.x
      Tracing: Active
      AutoPublishAlias: live
      DeploymentPreference:
        Type: Canary10Percent5Minutes
        Alarms:
          - !Ref HelloWorldServerErrorAlarm
      Events:
        CatchAll:
          Type: Api
          Properties:
            Path: /hello
            Method: GET
[...]
{{</ highlight >}}
