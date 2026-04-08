#!/usr/bin/env bats
# integration_aws.bats — AWS account connectivity and identity tests
# Requires: valid AWS credentials

load integration_helper

setup() {
  check_aws_credentials || skip "No AWS credentials available"
}

# ---------------------------------------------------------------------------
# Credentials and identity
# ---------------------------------------------------------------------------

@test "AWS credentials are valid" {
  run aws sts get-caller-identity --output text
  [ "$status" -eq 0 ]
  [[ "$output" == *"arn:aws"* ]]
}

@test "AWS account ID is a 12-digit number" {
  run get_account_id
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{12}$ ]]
}

@test "AWS region is set" {
  run get_region
  [ "$status" -eq 0 ]
  [[ -n "$output" ]]
}

# ---------------------------------------------------------------------------
# EC2 permissions — read-only
# ---------------------------------------------------------------------------

@test "ec2:DescribeInstances is permitted" {
  run aws ec2 describe-instances --max-results 5 --output text \
    --query "Reservations[*].Instances[*].InstanceId"
  [ "$status" -eq 0 ]
}

@test "ec2:DescribeVpcs is permitted" {
  run aws ec2 describe-vpcs --output text --query "Vpcs[*].VpcId"
  [ "$status" -eq 0 ]
}

@test "ec2:DescribeSubnets is permitted" {
  run aws ec2 describe-subnets --output text --query "Subnets[*].SubnetId"
  [ "$status" -eq 0 ]
}

@test "ec2:DescribeInstanceTypes is permitted" {
  run aws ec2 describe-instance-types \
    --instance-types t3.micro \
    --query "InstanceTypes[].InstanceType" \
    --output text
  [ "$status" -eq 0 ]
  [ "$output" = "t3.micro" ]
}

@test "ec2:DescribeLaunchTemplates is permitted" {
  run aws ec2 describe-launch-templates --output text \
    --query "LaunchTemplates[*].LaunchTemplateName"
  [ "$status" -eq 0 ]
}

@test "ssm:GetParameter for Amazon Linux 2023 AMI is permitted" {
  run aws ssm get-parameter \
    --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query Parameter.Value --output text
  [ "$status" -eq 0 ]
  [[ "$output" == ami-* ]]
}

# ---------------------------------------------------------------------------
# VPC and subnet discovery (mirrors ecLaunch logic)
# ---------------------------------------------------------------------------

@test "at least one VPC exists" {
  run bash -c "aws ec2 describe-vpcs --query 'length(Vpcs)' --output text"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "at least one private subnet exists" {
  run bash -c "
    aws --output text ec2 describe-subnets \
      --filters 'Name=tag:Name,Values=*private*' \
      --query 'Subnets[*].SubnetId' | wc -w | tr -d ' '
  "
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}
