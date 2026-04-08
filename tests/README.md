# ecTools Test Suite

## Overview

The test suite is split into two categories:

| Type | Files | Requires |
|---|---|---|
| Unit | `test_*.bats` | bash, bats-core — no AWS account needed |
| Integration | `integration_*.bats` | bash, bats-core, valid AWS credentials |

---

## Unit Tests

Unit tests use mock `aws`, `ssh`, and `curl` commands from `tests/mocks/` to run
entirely offline. They cover argument parsing, config loading, validation logic,
error paths, and helper functions.

### Running

```bash
# Run all unit tests
bats tests/test_*.bats

# Or use the runner script
./tests/run_tests.sh
```

### Files

| File | What it tests |
|---|---|
| `test_tools_rc.bats` | Config loading precedence, AWS profile pre-parsing, credential check, region resolution, `promptAndSave` |
| `test_ecConnect.bats` | Argument parsing (`-L`, `-f`, `-u`, `-o`, `-n`), SSH key validation, owner filter, IP connection modes, SSM error detection |
| `test_ecLaunch.bats` | Argument parsing (`-t`, `-o`, `-s`, `-v`, `-T`, `--replace-tags`, `-n`), tag building, VPC/subnet resolution, multi-value instance type, defaults |
| `test_ecSetup.bats` | `--help`, `_readVar`, `_writeVar`, `_deployScripts`, default install paths |

### Mocks

| Mock | Replaces | Default behaviour |
|---|---|---|
| `tests/mocks/aws` | `aws` CLI | Returns canned responses; override with `AWS_MOCK_RESPONSES="pattern:response\|..."` |
| `tests/mocks/ssh` | `ssh` | Prints args and exits 0; override exit code with `SSH_MOCK_EXIT_CODE` |
| `tests/mocks/curl` | `curl` | Returns a mock IMDS token and `us-east-1a` as AZ; override with `CURL_MOCK_TOKEN` / `CURL_MOCK_METADATA` |

---

## Integration Tests

Integration tests run against a real AWS account. They make actual API calls and
verify that the scripts work end-to-end with live AWS resources.

> **Cost warning:** Tests marked `[LAUNCHES INSTANCE]` create real EC2 instances.
> They are skipped by default (`SKIP_LAUNCH_TESTS=1`). Set `SKIP_LAUNCH_TESTS=0`
> only when you intend to incur the cost and are prepared to clean up.

### Prerequisites

- Valid AWS credentials (`aws configure`, SSO, or instance role)
- IAM permissions as described in `docs/iam-policy-ecLaunch.json` and `docs/iam-policy-ecConnect.json`
- At least one VPC with private subnets tagged with a name containing `rivate`
- `bats-core` installed

### Running

```bash
# Run all integration tests (launch tests skipped by default)
./tests/run_integration_tests.sh

# Run with a specific AWS profile
AWS_PROFILE=myprofile ./tests/run_integration_tests.sh

# Enable live launch tests (incurs cost)
SKIP_LAUNCH_TESTS=0 ./tests/run_integration_tests.sh

# Run a single integration file
bats tests/integration_aws.bats
```

### Configuration

All settings are passed as environment variables:

| Variable | Default | Description |
|---|---|---|
| `IT_TAG_KEY` | `Name` | EC2 tag key used to filter test instances |
| `IT_TAG_VALUE` | `ectools-test-*` | EC2 tag value pattern for test instances |
| `IT_INSTANCE_TYPE` | `t3.micro` | Instance type used for launch tests |
| `IT_PROJECT` | `ectools-integration-test` | Project tag applied to launched instances |
| `IT_SSH_KEY` | *(unset)* | Path to SSH private key for ecConnect tests |
| `IT_SSH_USER` | `ec2-user` | SSH username for ecConnect tests |
| `SKIP_LAUNCH_TESTS` | `1` | Set to `0` to enable tests that launch instances |
| `SKIP_CONNECT_TESTS` | *(unset)* | Set to `1` to skip tests that require a running instance |

### Files

| File | What it tests |
|---|---|
| `integration_aws.bats` | AWS credentials, IAM permissions, VPC/subnet availability, AMI resolution |
| `integration_ecConnect.bats` | Instance listing, `--dry-run` output, owner tag filtering, SSM plugin presence |
| `integration_ecLaunch.bats` | `--dry-run` resolves AMI/subnet/VPC/tags; live launch and tag verification (skipped by default) |

### GitHub Actions

Integration tests run automatically when:
- The workflow is triggered manually via **Actions → Run workflow**
- A commit message contains `[integration]`

They require an `aws-integration` GitHub environment with the following secrets/variables:

| Name | Type | Description |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Secret | IAM access key |
| `AWS_SECRET_ACCESS_KEY` | Secret | IAM secret key |
| `AWS_REGION` | Variable | AWS region (e.g. `us-east-1`) |

---

## Adding New Tests

### Unit test

1. Add a `@test` block to the appropriate `test_*.bats` file.
2. Use `run bash -c "..."` to isolate the test in a subshell.
3. Use `$MOCKS_DIR` in the PATH to intercept AWS calls.
4. Use `setup_test_home` / `teardown_test_home` from `test_helper.bash` to isolate the home directory.

### Integration test

1. Add a `@test` block to the appropriate `integration_*.bats` file.
2. Call `check_aws_credentials || skip "..."` at the top of `setup()`.
3. Use `skip_if` for conditional skipping (e.g. no matching instances, feature flags).
4. Always clean up any resources created (call `terminate_instance` for launched instances).
5. Prefix test names with `[LAUNCHES INSTANCE]` if they create billable resources.
