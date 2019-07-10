#!/bin/bash

# User variable
DESCRIPTION="Joe home"

# enviroment variables
AWSOUTPUT=text
AWSREGION=eu-west-1

# system variables
AWSCMD="aws ec2 --output $AWSOUTPUT --region $AWSREGION"
# Get new IP from an external site and add mask
NEWIP="$(curl -s v4.ifconfig.co)/32"

# Part 1: get a lisy of all SG matching the Description
SECURITYGROUPS=$($AWSCMD describe-security-groups  --query "SecurityGroups[?IpPermissions[?IpRanges[?Description=='$DESCRIPTION']]].[GroupId]")
# Part 2: Create array from the list of groups and get a list of Permiisions (IP and Ports)
IFS=$'\n' read -r -a SECURITYGROUP -d '' <<< "$SECURITYGROUPS"
echo $SECURITYGROUPS
echo ===============
# For each security group
for i in "${SECURITYGROUP[@]}"
do
        SECURITYGROUP=$i
        IPPERMISSIONS=$($AWSCMD describe-security-groups  --group-id $i --query "SecurityGroups[?IpPermissions[?IpRanges[?Description=='$DESCRIPTION']]].IpPermissions[*].[IpRanges[0].CidrIp,IpProtocol,FromPort,ToPort]")
# Part 3
        IFS=$'\n' read -r -a IPPERMISSION -d '' <<< "$IPPERMISSIONS"
        for j in "${IPPERMISSION[@]}"
        do
                OLDIP=$(echo "$j" | awk '{print $1}')
                PROTOCOL=$(echo "$j" | awk '{print $2}')
                PORT=$(echo "$j" | awk '{print $3}')
        done
done

exit 1


$AWSCMD revoke-security-group-ingress \
        --group-id $SECURITYGROUPID \
        --protocol tcp \
        --port $PORT \
        --cidr "$MYOLDIP"

$AWSCMD authorize-security-group-ingress \
        --group-id $SECURITYGROUPID \
        --protocol tcp \
        --port 22 \
        --cidr $MYNEWIP
