# aws
scripts for AWS

# ecConnect
A script to connect to and instance from a list in instances that are tagged as available for ssh connections.
## Usage

ecConnect [ *number* | random | *instanceID* ]

Runnig without any parameters will show a list of available instances with a number. You can select the number from the list or: **0** for a reandom host, **x** to exit.

***number*** A number from the list of a vailable instances

**random** A random host from the available instances

***instanceId*** The instancd ID from the available instances

## Requirments
* aws cli configured
* aws user with access to read tags
```json
{
  "Effect": "Allow",
  "Action": "ec2:Describe*",
  "Resource": "*"
}
```
* tags indicating the available instances
* Security group rule providing ssh access

## Configuration
* Tag your instances with the tags used to identify them as ssh accesiable.

# sgUpdate
Update the security groups for your used with the current IP in your location. 

## Usage
sgUpdat [ list ]

## Requirments
* aws cli
* jq (optional, but makes the script work faster, as repeated aws cli requests are not needed)
* aws user with permissions to read and update security group rules (you can limit the permissions to specific security groups and users)
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
                "ec2:DescribeSecurityGroups",
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
```
