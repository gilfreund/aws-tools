#!/bin/bash

# == Script Config ===================

# The rule description is used to determine the rule that should be updated.

USER="$(aws iam get-user --query User.UserName)"
RULE_DESCRIPTION="user:$USER"
SECURITYGROUPS=$(aws ec2 --output text describe-security-groups  --query "SecurityGroups[?IpPermissions[?IpRanges[?Description=='$RULE_DESCRIPTION']]].[GroupId]")
SECURITY_GROUP_NAME=My-Security-Group-Name

if [[ $1 == "test" ]] ; then
    echo USER $USER
    echo RULE_DESCRIPTION $RULE_DESCRIPTION
    echo SECURITYGROUPS $SECURITYGROUPS
    echo SECURITY_GROUP_NAME $SECURITY_GROUP_NAME
    aws --output text ec2 describe-security-groups --query "SecurityGroups[?IpPermissions[?IpRanges[?Description=='$RULE_DESCRIPTION']]].{A:GroupName,B:GroupId,C:IpPermissions[*].IpRanges[?Description=='$RULE_DESCRIPTION'].CidrIp,D:IpPermissions[0].IpProtocol,E:IpPermissions[0].FromPort,F:IpPermissions[0].ToPort}"
    exit
fi


# ====================================

OLD_CIDR_IP=`aws ec2 describe-security-groups --query "SecurityGroups[?GroupName=='"$SECURITY_GROUP_NAME"'].IpPermissions[*].IpRanges[?Description=='"$RULE_DESCRIPTION"'].CidrIp" --output text`
NEW_IP=`curl -s http://checkip.amazonaws.com`
NEW_CIDR_IP=$NEW_IP'/32'

# If IP has changed and the old IP could be obtained, remove the old rule
if [[ $OLD_CIDR_IP != "" ]] && [[ $OLD_CIDR_IP != $NEW_CIDR_IP ]]; then
    aws ec2 revoke-security-group-ingress --group-name $SECURITY_GROUP_NAME --protocol tcp --port 8080 --cidr $OLD_CIDR_IP
fi

# If the IP has changed and the new IP could be obtained, create a new rule
if [[ $NEW_IP != "" ]] && [[ $OLD_CIDR_IP != $NEW_CIDR_IP ]]; then
   aws ec2 authorize-security-group-ingress --group-name $SECURITY_GROUP_NAME --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 8080, "ToPort": 8080, "IpRanges": [{"CidrIp": "'$NEW_CIDR_IP'", "Description": "'$RULE_DESCRIPTION'"}]}]'
fi