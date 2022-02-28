# aws
This are scripts I use to make my life easier in accessing and managing AWS
---

# ecConnect
A script to connect to and instance from a list in instances that are tagged as available for ssh connections.
## Usage

ecConnect [ *number* | random | *instanceID* | list ]

Running without any parameters will show a list of available instances with a number. You can select the number from the list or: **0** for a random host, **x** to exit. eg:
```
$ ./ecConnect.sg
0:  Any host (rendom selection)
1:  Host-02 is i-11111111111111111 (r5d.large) on ec2-34-251-20-11.eu-west-1.compute.amazonaws.com (34.251.20.11)
2:  Host-01 is i-22222222222222222 (r5d.large) on ec2-34-252-20-12.eu-west-1.compute.amazonaws.com (34.252.20.22)
3:  Host-03 is i-33333333333333333 (r5d.large) on ec2-34-252-20-13.eu-west-1.compute.amazonaws.com (34.253.20.13)
x:  Exit
Select host (0 for a random host, x to exit):
```

* ***number*** A number from the list of a available instances
* **random** A random host from the available instances
* ***instanceId*** The instance ID from the available instances
* ***list*** Returns a list of the available instances

## Requirments
* The aws.functions file
* [Bash](https://www.gnu.org/software/bash/)
* [AWS CLI](https://aws.amazon.com/cli/)
* [ssh](https://www.openssh.com/) with a private key to connect to the Ec2 instance
* [tags](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Using_Tags.html) indicating the available instances
* [Security group](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html) [rule(s)](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html#SecurityGroupRules) providing ssh access
* [aws iam user](https://aws.amazon.com/iam/) with access to read tags, eg:
```json
{
  "Effect": "Allow",
  "Action": "ec2:Describe*",
  "Resource": "*"
}
```
## Configuration
Default configurable variables are in the ecConnect.vars file
* Tag your instances with the tags used to identify them as ssh accessible. e.g.
```bash
#!/usr/bin/env bash
# vim:ft=sh
export SSH_KEY=""
# [-i identity_file]
export SSH_FORWARD=""
# -X -L [bind_address:]port:host:hostport
# -X -f -L [bind_address:]port:host:hostport
SSH_USER=$(runAwsCommand --output text iam get-user --query User.UserName)
export SSH_USER
export TAG_KEY=Name
export TAG_VALUE="ComputeDevelopment*"
```
You can overwrite the values in ecConnect.vars by creating an ecConnect.vars.local file with your own parameters that will overwrite the the values in ecConnect.vars
```bash
# Use the ec2-user user and key
SSH_USER="ec2-user"
export SSH_USER
export SSH_KEY="~/.ssh/ec2-user.key"
```
* Set the used id connecting to the instance. By default, the script uses the IAM username, which is only useful if the IAM and Linux users are the same. 
```shell
SSH_USER=$(aws --output text  iam get-user --query User.UserName)
```
---

# sgUpdate
Update the security groups for your user with the current IP in your location. 

## Usage
sgUpdate [ list | listall | update ]
* **list** List all ingress security group rules for your user
* **listall** List all ingress security groups
* **update** Update your users' security group rule with the current IP

## Requirements
* The aws.functions file
* the ecConnect.vars file
* (optional) a ecConnect.vars.local file
* [Bash](https://www.gnu.org/software/bash/)
* [curl](https://curl.se/)
* [AWS CLI](https://aws.amazon.com/cli/)
* [jq](https://stedolan.github.io/jq/) (Optional) 
  * The will makes the script work faster, as fewer aws cli requests are needed - 3 instead of 7)
  * If jq is used, the supporting filter file is also required. The filter code is based on [Parse aws cli output security groups with JQ](https://stackoverflow.com/questions/26543318/parse-aws-cli-output-security-groups-with-jq/45704642#45704642) by [jq170727](https://stackoverflow.com/users/8379597/jq170727)
* [aws iam user](https://aws.amazon.com/iam/) with permissions to read and update security group rules (you can limit the permissions to specific security groups and users), eg:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "ArnEquals": {
                    "ec2:Vpc": "arn:aws:ec2:*:*:vpc/vpc-vpc-id"
                }
            }
        },
        {
            "Action": [
                "ec2:DescribeSecurityGroups"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
```


# ecLaunch
Launch a new instance based on a template with a few override 

## Usage
ecLaunch [ -t | --type INSTANCETYPE ] [ -o | --owner OWNERTAG ] [ -p | --project PROJECT]

-t | --type INSTANCETYPE    AWS ec2 Instance type
-o | --owner OWNERTAG       An owner tag, used for accounting
-p | --project PROJECT      A Project tag, used to accounting

The script will attempt to launch the appropriate AMI for the hardware architecture of the instance select.
* Supported:
** ARM64:    t4g|m6g|a1|c7g|c6g|c6gn|r6g|x2gd|im4gn|is4gen
** x86_64 with GPU:  p4|p3|p2|g5|g5dn|g3
** AWS ML chip: dl1|trn1|inf1
** x86_64: all other
* Unsupported
** FPG: f1
** Media Accelerator: vt1
** AMD GPU: g5ad
** ARM64 with GPU: g5g

## Requirements
* The aws.functions file
* the ecLaunch.vars file
* (optional) a ecLaunch.vars.local file
* [Bash](https://www.gnu.org/software/bash/)
* [curl](https://curl.se/)
* [AWS CLI](https://aws.amazon.com/cli/)
* [aws iam user](https://aws.amazon.com/iam/) with access to launch ec2 instance and update tags
* The subnets that are available for the instance shout be tagged, and the tags name and value specified ecLaunch.vars

Launching with no parameters will launch based on the parameters set in ecLaunch.vars

## Configuration
All user configurable variables are in the ecLaunch.vars file
```bash
# instance type and launch template 
export INSTANCETYPE="r5d.large"
export LAUNCHTEMPLATE="lt-06040c9074848c8b7"
# Instance and volume tagging 
export NAMEPREFIX="ComputeDevelopment"
export PROJECT="unknown"
# Subnet tags for usable subnets
export SUBNETTAGNAME="Service"
export SUBNETTAGVALUE="Compute"
```
You can overwrite the values in ecLaunch.vars by creating an ecLaunch.vars.local file with your own parameters that will overwrite the the values in ecLaunch.vars
```bash
# My Templates
export LAUNCHTEMPLATE="lt-06040c9074848c8b7"
# My default project
export PROJECT="stuff"
```
# Support files
## aws.functions
This externalizes the aws command to a function in order to add jitter to the command to avoid a situation where it might fail to API throttling and returning 429 Too Many Requests. See:
* https://docs.aws.amazon.com/AWSEC2/latest/APIReference/throttling.html
* https://docs.aws.amazon.com/general/latest/gr/api-retries.html


