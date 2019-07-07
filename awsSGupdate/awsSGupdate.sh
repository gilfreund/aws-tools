#!/bin/bash
# script to pull my current public IP address 
# and add a rule to my EC2 security group allowing me SSH access 
SGN=EC2
SGID=$(/usr/local/bin/aws ec2 describe-security-groups --group-names EC2 | grep "SECURITYGROUPS" | awk -F'\t' '{print $3}')

MYOLDIP=/usr/local/bin/aws ec2 describe-security-groups --group-names $SGN | grep "Gil Home" | awk '{print $2}'

	--group-name $SGN \
	--protocol tcp \
	--port 22 \

aws ec2 revoke-security-group-egress \
	--group-id sg-1a2b3c4d \
	--ip-permissions '[{"IpProtocol": "tcp", "FromPort": 80, "ToPort": 80, "IpRanges": [{"CidrIp": "10.0.0.0/16"}]}]'

MYIP="$(curl -s v4.ifconfig.co)/32"
aws ec2 authorize-security-group-ingress \
	--group-name $SGN \
	--protocol tcp \
	--port 22 \
--cidr $MYIP
