# Update a a secutiry group rule to your local address. 
AS I moved between networks, or as network public addresses changed, updating the security group rules became a burdon. I needed a tool or script to update my access on the fly.

# Requirments
## Software
* Mac or Linux with [bash](https://www.gnu.org/software/bash/) and [awk](https://github.com/onetrueawk/awk)
* [AWS Command Line interface](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html), installed and configured.
## Security Group rule descriptions
This tool require a uniqe description to all the security groups rule you will want it to change. I am using the convention **name:_user_**, so it can be used by multiple users. This, in turn, requires that each user will have a unique ID and Key.
## Notes
* For multiuser enviroment, each user will need a unique ID and Key.
* The script will overwride the .aws configuration of zone and output.
* security group rules are CaSe SeNsAtIve.

# Credits:
[A Bash Script to Update an Existing AWS Security Group with My New Public IP Address](https://medium.com/@dbclin/a-bash-script-to-update-an-existing-aws-security-group-with-my-new-public-ip-address-d0c965d67f28) by [David Clinton](https://medium.com/@dbclin)
