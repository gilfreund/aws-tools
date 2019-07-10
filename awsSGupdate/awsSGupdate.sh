#!/bin/bash
AWSOUTPUT=text
AWSREGION=eu-west-1
DESCRIPTION="Joe home"
AWSCMD="aws ec2 --output $AWSOUTPUT --region $AWSREGION"


# Get old IP from AWS based on description
MYOLDIP=$($AWSCMD describe-security-groups --group-names $SGN | grep "$DESCRIPTION" | awk '{print $2}' )
# Get new IP from an external site and add mask
MYNEWIP="$(curl -s v4.ifconfig.co)/32"


# SECURITYGROUPNAME=EC2
# List of all SG matching the Description
SECURITYGROUPS=$($AWSCMD describe-security-groups --query "SecurityGroups[?IpPermissions[?IpRanges[?Description=='$DESCRIPTION']]].[GroupId]")
#Create array from the list of groups
IFS=$'\n' read -r -a SECURITYGROUP -d '' <<< "$SECURITYGROUPS"
# For each security group
for i in "${SECURITYGROUP[@]}"
do
        SECURITYGROUP=$i
        echo "Group $SECURITYGROUP"
        $AWSCMD describe-security-groups --group-id $i | grep "DESCRIPTION"
        #| awk -F'\t' '{print $3}'
done

exit 1
$AWSCMD revoke-security-group-ingress \
        --group-id $SECURITYGROUPID \
        --protocol tcp \
        --port 22 \
        --cidr "$MYOLDIP"

$AWSCMD authorize-security-group-ingress \
        --group-id $SECURITYGROUPID \
        --protocol tcp \
        --port 22 \
        --cidr $MYNEWIP
