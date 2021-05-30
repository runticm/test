#!/bin/bash

#
# simple script calling AWS API to create resources through AWS CLI tool
#
# requirements:
#	- AWS CLI tool installed
# 	- AWS credentials for AWS CLI configured
# 	- KeyPair generated for EC2 instances
#
# adjust variables per need: 
#	- $REGION 
#	- $PROFILE if using profiles when authenticating with AWS API, otherwise leave empty
#	- $KEYPAIR


# General variables
REGION="eu-west-1"
PROFILE=""
# alias of KeyPair used to connect to instances
KEYPAIR="tqtest-keypair"

# CloudFormation stack names
ECSCLUSTER_STACKNAME="EcsClusterStack"
JENKINS_STACKNAME="Jenkins"

# ECR repository name
ECRREPO="tqtest-ecr-hello-world"


# set profile switch for AWS commands if $PROFILE variable is not ""
if [[ $PROFILE == "" ]]; then
	PROFILESWITCH=""
else
	PROFILESWITCH="--profile=$PROFILE"
fi

# create ECS cluster composed of two EC2 instances from ./EcsClusterStack cloudformation template
aws cloudformation deploy --template-file ./$ECSCLUSTER_STACKNAME --stack-name $ECSCLUSTER_STACKNAME --parameter-overrides KeyName=$KEYPAIR --tags "Key=env Value=dev" "Key=app Value=jenkins-server" "Key=cfn-stack Value=$ECSCLUSTER_STACKNAME" --capabilities CAPABILITY_IAM --region=$REGION $PROFILESWITCH

# create EC2 instance for Jenkins server from ./Jenkins cloudformation template
aws cloudformation deploy --template-file ./$JENKINS_STACKNAME --stack-name $JENKINS_STACKNAME --parameter-overrides KeyName=$KEYPAIR --tags "Key=env Value=dev" "Key=app Value=jenkins-server" "Key=cfn-stack Value=$ECSCLUSTER_STACKNAME" --capabilities CAPABILITY_IAM --region=$REGION $PROFILESWITCH
 
# create ECR repository
CHECK_REPO=$(aws ecr describe-repositories $PROFILESWITCH | grep "repositoryName" | grep "$ECRREPO")
if [[ -n $CHECK_REPO ]]; then
	echo "Repository $ECRREPO already exists"
else
	aws ecr create-repository --repository-name $ECRREPO --tags "Key=env Value=dev" "Key=app Value=jenkins-server" "Key=cfn-stack Value=$ECSCLUSTER_STACKNAME" --region=$REGION $PROFILESWITCH
fi
