# ecTools CloudFormation

## identity-center.yaml

Creates IAM Identity Center permission sets that grant the minimum permissions
needed to run ecConnect and ecLaunch.

### Permission sets created

| Name | Scripts | Access |
|---|---|---|
| `ecTools-ecConnect` | ecConnect only | Read-only: list instances, SSM tunnel |
| `ecTools-ecLaunch` | ecLaunch only | Read + write: discover resources, launch instances |
| `ecTools-FullAccess` | Both | Combined permissions |

### Prerequisites

- IAM Identity Center must already be enabled in your AWS account or management account.
- You need the IAM Identity Center instance ARN (find it under **IAM Identity Center → Settings**).

### Deploy

```bash
aws cloudformation deploy \
  --template-file docs/cloudformation/identity-center.yaml \
  --stack-name ectools-identity-center \
  --parameter-overrides \
    IdentityCenterInstanceArn=arn:aws:sso:::instance/ssoins-XXXXXXXXXX \
    TargetAccountId=123456789012 \
    SessionDurationHours=8 \
  --capabilities CAPABILITY_IAM
```

### Assign users

After deploying, assign users or groups to the permission sets via the console
or CLI:

```bash
# Assign a user to the ecTools-FullAccess permission set in the target account
aws sso-admin create-account-assignment \
  --instance-arn arn:aws:sso:::instance/ssoins-XXXXXXXXXX \
  --target-id 123456789012 \
  --target-type AWS_ACCOUNT \
  --permission-set-arn <PermissionSetEcToolsArn from stack outputs> \
  --principal-type USER \
  --principal-id <user-id-from-identity-center>
```

### Configure ecTools to use SSO

Add the following to `~/.config/ecTools/ecTools.conf`:

```bash
EC_AWS_PROFILE=my-sso-profile
```

Or pass it at runtime:

```bash
ecConnect -p my-sso-profile
ecLaunch   -p my-sso-profile -t t3.medium
```

To configure the AWS CLI profile for SSO:

```bash
aws configure sso \
  --profile my-sso-profile \
  --sso-start-url https://my-org.awsapps.com/start \
  --sso-region us-east-1 \
  --sso-account-id 123456789012 \
  --sso-role-name ecTools-FullAccess
```

Then log in before running the scripts:

```bash
aws sso login --profile my-sso-profile
ecConnect -p my-sso-profile
```
