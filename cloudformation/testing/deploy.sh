#!/usr/bin/env bash
# deploy.sh — deploy ecTools integration test stacks
#
# Usage:
#   ./cloudformation/testing/deploy.sh [--multi-vpc] [--ec2] [--identity-center] [--destroy]
#
# Options:
#   --multi-vpc          Also deploy the multi-VPC stack (3 VPCs total)
#   --ec2                Also deploy EC2 test instances (requires --key-pair)
#   --identity-center    Also deploy IAM Identity Center permission sets
#   --key-pair NAME      EC2 key pair name (required with --ec2)
#   --region REGION      AWS region (default: from AWS config)
#   --account ACCOUNT    AWS account ID (required for Identity Center)
#   --sso-instance ARN   IAM Identity Center instance ARN (required with --identity-center)
#   --sso-user-id ID     Identity Center user ID to assign permission sets to
#   --destroy            Tear down all test stacks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGION="${AWS_DEFAULT_REGION:-$(aws configure get region 2>/dev/null || echo us-east-1)}"

# Stack names
STACK_IAM="ectools-test-iam"
STACK_VPC_SINGLE="ectools-test-vpc-single"
STACK_VPC_MULTI="ectools-test-vpc-multi"
STACK_EC2="ectools-test-ec2"

# Flags
DEPLOY_MULTI_VPC=0
DEPLOY_EC2=0
DEPLOY_IDENTITY_CENTER=0
DESTROY=0
KEY_PAIR=""
ACCOUNT_ID=""
SSO_INSTANCE_ARN=""
SSO_USER_ID=""

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    --multi-vpc)         DEPLOY_MULTI_VPC=1; shift ;;
    --ec2)               DEPLOY_EC2=1; shift ;;
    --identity-center)   DEPLOY_IDENTITY_CENTER=1; shift ;;
    --key-pair)          KEY_PAIR="$2"; shift 2 ;;
    --region)            REGION="$2"; shift 2 ;;
    --account)           ACCOUNT_ID="$2"; shift 2 ;;
    --sso-instance)      SSO_INSTANCE_ARN="$2"; shift 2 ;;
    --sso-user-id)       SSO_USER_ID="$2"; shift 2 ;;
    --destroy)           DESTROY=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--multi-vpc] [--ec2] [--identity-center] [--destroy]"
      echo "          [--key-pair NAME] [--region REGION] [--account ACCOUNT_ID]"
      echo "          [--sso-instance ARN] [--sso-user-id ID]"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
if [[ $DEPLOY_EC2 -eq 1 && -z "$KEY_PAIR" ]]; then
  echo "ERROR: --ec2 requires --key-pair NAME"
  exit 1
fi

if [[ $DEPLOY_IDENTITY_CENTER -eq 1 && -z "$SSO_INSTANCE_ARN" ]]; then
  echo "ERROR: --identity-center requires --sso-instance ARN"
  exit 1
fi

if [[ -z "$ACCOUNT_ID" ]]; then
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
fi

# ---------------------------------------------------------------------------
# Destroy mode
# ---------------------------------------------------------------------------
if [[ $DESTROY -eq 1 ]]; then
  echo "==> Destroying ecTools test stacks..."
  for stack in "$STACK_EC2" "$STACK_VPC_MULTI" "$STACK_VPC_SINGLE" "$STACK_IAM"; do
    if aws cloudformation describe-stacks --stack-name "$stack" --region "$REGION" &>/dev/null; then
      echo "  Deleting $stack..."
      aws cloudformation delete-stack --stack-name "$stack" --region "$REGION"
      aws cloudformation wait stack-delete-complete --stack-name "$stack" --region "$REGION"
      echo "  Deleted $stack"
    else
      echo "  $stack not found, skipping."
    fi
  done
  echo "Done."
  exit 0
fi

# ---------------------------------------------------------------------------
# Deploy helper
# ---------------------------------------------------------------------------
deploy_stack() {
  local stackName="$1"
  local templateFile="$2"
  shift 2
  local params=("$@")

  echo ""
  echo "==> Deploying $stackName..."
  aws cloudformation deploy \
    --stack-name "$stackName" \
    --template-file "$templateFile" \
    --region "$REGION" \
    --capabilities CAPABILITY_NAMED_IAM \
    ${params:+--parameter-overrides "${params[@]}"}
  echo "  $stackName deployed."
}

# ---------------------------------------------------------------------------
# Deploy stacks
# ---------------------------------------------------------------------------
echo "Deploying ecTools integration test infrastructure"
echo "  Region:  $REGION"
echo "  Account: $ACCOUNT_ID"
echo ""

# 1. IAM
_iamParams=("TargetAccountId=$ACCOUNT_ID")
[[ -n "$SSO_INSTANCE_ARN" ]] && _iamParams+=("IdentityCenterInstanceArn=$SSO_INSTANCE_ARN")
[[ -n "$SSO_USER_ID" ]]      && _iamParams+=("IdentityCenterUserId=$SSO_USER_ID")
deploy_stack "$STACK_IAM" "$SCRIPT_DIR/iam.yaml" "${_iamParams[@]}"

# 2. Single VPC
deploy_stack "$STACK_VPC_SINGLE" "$SCRIPT_DIR/vpc-single.yaml"

# 3. Multi VPC (optional)
if [[ $DEPLOY_MULTI_VPC -eq 1 ]]; then
  deploy_stack "$STACK_VPC_MULTI" "$SCRIPT_DIR/vpc-multi.yaml"
fi

# 4. EC2 instances (optional)
if [[ $DEPLOY_EC2 -eq 1 ]]; then
  deploy_stack "$STACK_EC2" "$SCRIPT_DIR/ec2.yaml" \
    "VpcSingleStackName=$STACK_VPC_SINGLE" \
    "KeyPairName=$KEY_PAIR"
fi

# ---------------------------------------------------------------------------
# Print integration test env vars
# ---------------------------------------------------------------------------
echo ""
echo "==> Stack outputs — set these before running integration tests:"
echo ""

_accessKey=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_IAM" --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='IamAccessKeyId'].OutputValue" \
  --output text)
_secretKey=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_IAM" --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='IamSecretAccessKey'].OutputValue" \
  --output text)

cat << ENV
export AWS_ACCESS_KEY_ID="$_accessKey"
export AWS_SECRET_ACCESS_KEY="$_secretKey"
export AWS_DEFAULT_REGION="$REGION"
export IT_TAG_KEY="Name"
export IT_TAG_VALUE="ectools-test-*"
export IT_INSTANCE_TYPE="t3.micro"
export IT_PROJECT="ectools-integration-test"
ENV

if [[ $DEPLOY_EC2 -eq 1 ]]; then
  echo "export IT_SSH_KEY=\"-i ~/.ssh/${KEY_PAIR}.pem\""
fi

echo ""
echo "Then run: ./tests/run_integration_tests.sh"
