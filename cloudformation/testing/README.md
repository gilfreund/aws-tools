# ecTools Integration Test Infrastructure

CloudFormation stacks that provision the AWS resources needed to run the
integration test suite against a real account.

## Stacks

| Stack file | Purpose |
|---|---|
| `iam.yaml` | IAM user + access key + Identity Center permission sets |
| `vpc-single.yaml` | One VPC with public and private subnets (single-VPC scenario) |
| `vpc-multi.yaml` | Two additional VPCs (multi-VPC selection scenario) |
| `ec2.yaml` | Two t3.micro instances tagged for ecConnect tests |

## Quick start

```bash
# Minimal — IAM user + single VPC only (no EC2 instances, no Identity Center)
./cloudformation/testing/deploy.sh

# With EC2 instances for ecConnect tests
./cloudformation/testing/deploy.sh --ec2 --key-pair my-key

# Full setup — multi-VPC + EC2 + Identity Center
./cloudformation/testing/deploy.sh \
  --multi-vpc \
  --ec2 --key-pair my-key \
  --identity-center \
  --sso-instance arn:aws:sso:::instance/ssoins-XXXXXXXXXX \
  --sso-user-id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# Tear everything down
./cloudformation/testing/deploy.sh --destroy
```

## What each stack creates

### iam.yaml

- **IAM user** `ectools-integration-test` with an access key and a managed
  policy granting the exact permissions needed by ecConnect and ecLaunch,
  plus `ec2:TerminateInstances` scoped to instances tagged
  `project=ectools-integration-test`.
- **Identity Center permission sets** `ecTools-ecConnect-test` and
  `ecTools-ecLaunch-test` (optional — only created when
  `IdentityCenterInstanceArn` is provided).
- **Identity Center assignments** to a specific user (optional — only when
  `IdentityCenterUserId` is also provided).

### vpc-single.yaml

Creates one VPC (`10.10.0.0/16`) with:
- 2 private subnets tagged `ectools-test-private-*` (matched by the default
  `EC_SUBNET_FILTER=*private*`)
- 2 public subnets tagged `ectools-test-public-*`
- Internet Gateway + NAT Gateway (private subnets need outbound HTTPS for
  the SSM agent)

### vpc-multi.yaml

Creates two more VPCs (`10.20.0.0/16` and `10.30.0.0/16`), each with one
private subnet. Together with `vpc-single.yaml` this gives three VPCs,
which triggers ecLaunch's interactive VPC selection menu.

### ec2.yaml

Launches two `t3.micro` instances in the private subnets of the single VPC:
- Tagged `Name=ectools-test-instance-1` and `ectools-test-instance-2`
- Tagged `owner=ectools-test`, `project=ectools-integration-test`
- Attached IAM role with `AmazonSSMManagedInstanceCore` (enables SSM mode)
- No inbound SSH — access via SSM only

## Running the integration tests

After deploying, the `deploy.sh` script prints the environment variables to
set. Copy and export them, then run:

```bash
./tests/run_integration_tests.sh
```

To also run the live launch tests (which create and terminate instances):

```bash
SKIP_LAUNCH_TESTS=0 ./tests/run_integration_tests.sh
```

## Scenarios covered

| Scenario | Stacks needed |
|---|---|
| Single VPC subnet discovery | `iam` + `vpc-single` |
| Multi-VPC selection menu | `iam` + `vpc-single` + `vpc-multi` |
| ecConnect instance listing | `iam` + `vpc-single` + `ec2` |
| ecConnect SSM mode | `iam` + `vpc-single` + `ec2` |
| IAM user authentication | `iam` |
| Identity Center SSO authentication | `iam` (with SSO params) |
