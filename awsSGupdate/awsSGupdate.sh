#!/bin/bash

# User variablea
AWSREGION=eu-west-1

# system variables
if [ -z "$USER" ]
then
        echo "DESCRIPTION is not defined"
        exit 1
fi
AWSOUTPUT=text
AWSCMD="aws ec2 --output $AWSOUTPUT --region $AWSREGION"
# Get new IP from an external site and add mask
NEWIP="$(curl -s v4.ifconfig.co)/32"
USER="$(aws iam --output text get-user| awk '{printf $7}')"
DESCRIPTION="user:$USER"

# Part 1: get a lisy of all SG matching the Description
SECURITYGROUPS=$($AWSCMD describe-security-groups  --query "SecurityGroups[?IpPermissions[?IpRanges[?Description=='$DESCRIPTION']]].[GroupId]")
if [ -z "$SECURITYGROUPS" ]
then
        echo "No Security Groups found based on the DESCRIPTION $DESCRIPTION"
        exit 1
fi
# Part 2: Create array from the list of groups and get a list of Permiisions (IP and Ports)
IFS=$'\n' read -r -a SECURITYGROUP -d '' <<< "$SECURITYGROUPS"
# For each security group
for i in "${SECURITYGROUP[@]}"
do
        SECURITYGROUPID=$i
        echo Security Group $SECURITYGROUP
        echo ================================
        echo -e "Old IP\t\t\tProt\tFrom\tTo\t"
        IPPERMISSIONS=$($AWSCMD describe-security-groups  --group-id $i --query "SecurityGroups[?IpPermissions[?IpRanges[?Description=='$DESCRIPTION']]].IpPermissions[*].{a:IpRanges[0].CidrIp,b:IpProtocol,c:FromPort,d:ToPort}")
# Part 3
        IFS=$'\n' read -r -a IPPERMISSION -d '' <<< "$IPPERMISSIONS"
        for j in "${IPPERMISSION[@]}"
        do
                OLDIP=$(echo "$j" | awk '{print $1}')
                PROTOCOL=$(echo "$j" | awk '{print $2}')
                FROMPORT=$(echo "$j" | awk '{print $3}')
                TOPORT=$(echo "$j" | awk '{print $4}')
                echo -e "$OLDIP\t$PROTOCOL\t$FROMPORT\t$TOPORT"
                $AWSCMD revoke-security-group-ingress \
                --group-id $SECURITYGROUPID \
                --ip-permissions IpProtocol=$PROTOCOL,FromPort=$FROMPORT,ToPort=$TOPORT,IpRanges="[{CidrIp=$OLDIP}]"

                $AWSCMD authorize-security-group-ingress \
                --group-id $SECURITYGROUPID \
                --ip-permissions IpProtocol=$PROTOCOL,FromPort=$FROMPORT,ToPort=$TOPORT,IpRanges="[{CidrIp=$NEWIP,Description=$DESCRIPTION}]"
        done
done
