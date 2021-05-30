tqtest-ecs-hello-world
======================
 
## Running locally

Build and run using Docker Compose:

`git@github.com:albin-typeqast/tqtest-deploy-ecs.git`  
`cd tqtest-deploy-ecs/`  
`docker-compose up`  
`localhost:80` 
    

## Create a personal GIT repository so you can make changes and push to repo (if you already have it skip it)
Create a personal repository on github or fork it  
Clone tqtest repo localy on your PC:
`git clone git@github.com:albin-typeqast/tqtest-deploy-ecs.git`  
CD into tqtest-deploy-ecs folder  
Delete the hidden .git directory with command rm -fR .git  
Reinitialize the repository and push the contents to your new GitHub repository using SSH by running the following command  
`git init`  
`git add .`  
`git commit -m "Initial commit"`  
If you are using SSH, run the following command:  
`git remote add origin 'git@github.com:<your_repo>.git'`  
If you are using HTTPS, run the following command:  
`git remote add origin 'https://github.com/<your_repo>.git'`  
Example:  
`git remote add origin 'https://github.com/SOME_PERSONAL_REPO/tqtest-deploy-ecs.git'`  
`git push -u origin master`  
Now you will be able to make changes to the code which will later trigger build and deploy on Jenkins server and activate it on the ECS service  


## Deploying to ECS

In AWS create key pair (if you already have it skip it)  
After download change permissions (if you already have it skip it)  
`chmod 400 <key_name>` (if you already have it skip it)  
`git@github.com:albin-typeqast/tqtest-deploy-ecs.git`  
`cd tqtest-deploy-ecs/`  

Fulfill requirements and adjust variables in **deploy-ecs-ecr-jenkins.sh** script  
Run `./deploy-ecs-ecr-jenkins.sh` script  
Script just executes three commands:  
  1. creates ECS cluster, networking and two EC2 instances used by the cluster (in private subnet using NATGateway to access the internet and ECS/ECR)  
  2. creates Jenkins server for deployment purposes (in public subnet just for simplicity of demonstration purposes)  
    - should be in private subnet with bastion instance for connecting to the Jenkins server, DO NOT USE IN PRODUCTION !!!  
  3. creates ECR repository  

You can also run the commands manually 


## Configure Jenkins
In EC2 console look for Jenkins instance and copy initial pass from syslog (search on the end of log for "**Jenkins initial password**")

Go to your favorite browser and paste public hostname of Jenkins server  
Paste password which you copy from previous step  
Choose Install suggested plugins  
Create your first admin user  
Go to tab Manage Jenkins and then Manage Plugins  
On Available tab choose **Amazon ECR** and **CloudBees Docker Build and Publish** plugin  
Then select Download now and install after restart  
Select **Restart Jenkins when installation is complete and no jobs are running**  
Refresh page after one min   


## Enable automatic trigger in Jenkins by adding webhook
In GitHub personal repo, click settings (**Not main settings! It is Repo settings**)  
Under settings, select **Webhooks**  
Add **Payload URL** of your Jenkins public hostname and add sufix github-webhook/ (**Note the slash character "/" at the end, without it, it won't work**)  
Example: *http://ec2-3-120-237-218.eu-central-1.compute.amazonaws.com/github-webhook/*    
Check active box before adding webhook  
Add webhook  


## Configure Jenkins job
Create a **freestyle project** in Jenkins and add name  

Under **source code management**, select **git** and type the name of personal GitHub repository you have created earlier, *https://github.com/SOME_PERSONAL_REPO/tqtest-deploy-ecs.git*  

Select Branch Specifier to */master  

Under **build triggers**, select **Github hook trigger for GITScm polling** in order to connect with Github webhook (as soon as we push our script from local environment to Github, Jenkins will be triggered sponteneously)  
Under **Build environment**, select **delete workspace before build starts**  

Add another build step with **execute shell** selected. In the command field, type or paste the following text: (ECR_REPO and REGION accordingly to your account)  

```
#!/bin/bash
set -x
sudo groupadd docker
sudo usermod -aG docker $USER
sudo chmod 777 /var/run/docker.sock
PATH=$PATH:/usr/local/bin; export PATH
REGION=eu-west-1
ECR_REPO="XXXXXXXXXXXX.dkr.ecr.eu-central-1.amazonaws.com/tqtest-ecr-hello-world"
#$(aws ecr get-login --region ${REGION})
aws ecr get-login --no-include-email --region ${REGION}>>login.sh
sh login.sh
```

Add another build step by selectting **docker build and publish**
On **Repository Name** add: *XXXXXXXXXXXX.dkr.ecr.eu-central-1.amazonaws.com/tqtest-ecr-hello-world* (accordingly to your account)  
On TAG add: *v_$BUILD_NUMBER*  
On Docker registry URL add: *http://XXXXXXXXXXXX.dkr.ecr.eu-central-1.amazonaws.com/tqtest-ecr-hello-world* (accordingly to your account)  

Add another build step by selecting **execute shell**. In the command field, type or paste the following text: (REGION accordingly to your account)  

```
#!/bin/bash
set -x
#Constants
PATH=$PATH:/usr/local/bin; export PATH
REGION=eu-west-1
REPOSITORY_NAME=tqtest-ecr-hello-world
CLUSTER=typeqast-workshop
FAMILY=`sed -n 's/.*"family": "\(.*\)",/\1/p' taskdef.json`
NAME=`sed -n 's/.*"name": "\(.*\)",/\1/p' taskdef.json`
SERVICE_NAME=${NAME}-service
env
aws configure list
echo $HOME
#Store the repositoryUri as a variable
REPOSITORY_URI=`aws ecr describe-repositories --repository-names ${REPOSITORY_NAME} --region ${REGION} | jq .repositories[].repositoryUri | tr -d '"'`
#Replace the build number and respository URI placeholders with the constants above
sed -e "s;%BUILD_NUMBER%;${BUILD_NUMBER};g" -e "s;%REPOSITORY_URI%;${REPOSITORY_URI};g" taskdef.json > ${NAME}-v_${BUILD_NUMBER}.json
#Register the task definition in the repository
aws ecs register-task-definition --family ${FAMILY} --cli-input-json file://${WORKSPACE}/${NAME}-v_${BUILD_NUMBER}.json --region ${REGION}
SERVICES=`aws ecs describe-services --services ${SERVICE_NAME} --cluster ${CLUSTER} --region ${REGION} | jq .failures[]`
#Get latest revision
REVISION=`aws ecs describe-task-definition --task-definition ${NAME} --region ${REGION} | jq .taskDefinition.revision`
#Create or update service
if [ "$SERVICES" == "" ]; then
  echo "entered existing service"
  DESIRED_COUNT=`aws ecs describe-services --services ${SERVICE_NAME} --cluster ${CLUSTER} --region ${REGION} | jq .services[].desiredCount`
  if [ ${DESIRED_COUNT} = "0" ]; then
    DESIRED_COUNT="1"
  fi
  aws ecs update-service --cluster ${CLUSTER} --region ${REGION} --service ${SERVICE_NAME} --task-definition ${FAMILY}:${REVISION} --desired-count ${DESIRED_COUNT}
else
  echo "entered new service"
  aws ecs create-service --service-name ${SERVICE_NAME} --desired-count 1 --task-definition ${FAMILY} --cluster ${CLUSTER} --region ${REGION}
fi
```

## Test everything
On your PC do folowing  
`git add .`  
`git commit -m "initial commit"`  
`git push`  
On Jenkins web page we see that job is triggered  
Go to AWS, EC2 console, under **Load balancers**, find the one we created and under **Description** tab copy the **DNS name**  
Paster the DNS name in the browser and the page should show up


  :) Hello world (:



## Exercise assignments:
### Create DNS in Route53 so page shows up under custom name on the internet    
Find some free domain provider and setup Route53 to resolve our page on new domain  
### Put Jenkins server in private subnet and setup bastion host in front  
Move jenkins EC2 instance to private subnet and configure bastion in public one with correct security groups
  
