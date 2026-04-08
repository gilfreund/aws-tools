# aws-tools

Bash scripts for connecting to and launching EC2 instances.

## Scripts

### ecConnect

Interactively lists running EC2 instances filtered by tag and opens an SSH session.

```
Usage: ecConnect [ -L | --forward SPEC ] [ -f | --fork ] [ -u | --user USER ]
                 [ -o | --owner OWNER ] [ -p | --profile PROFILE ] [ -h | --help ]
                 [ public | private | ssm ] [ random | i-<id> | <number> | list ]

  -L | --forward SPEC      SSH port forward, e.g. 8080:localhost:80 (may be repeated)
  -f | --fork              Fork SSH into background (-f -N, tunnel only)
  -u | --user USER         SSH username (overrides EC_SSH_USER from config)
  -o | --owner OWNER       Filter instances by owner tag value
  -p | --profile PROFILE   AWS CLI profile to use (overrides EC_AWS_PROFILE)
  -h | --help              Show this help
  public | private | ssm   Override EC_IP_CONNECTION from config
  random                   Connect to a random matching instance
  i-<id>                   Connect to a specific instance by ID
  <number>                 Connect to instance by list position
  list                     Print matching instances and exit
```

SSM mode (`ssm`) connects via AWS Session Manager — no open inbound ports required.
Requires the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).

### ecLaunch

Launches a new EC2 instance with automatic AMI selection based on instance type
architecture and accelerator. Launch template is optional.

```
Usage: ecLaunch [ -t | --type TYPE ] [ -o | --owner OWNER ] [ -a | --ami AMI ]
                [ -s | --subnet SUBNET-ID ] [ -v | --vpc VPC-ID ]
                [ -T | --tag Key=Value ] [ --replace-tags ]
                [ -p | --profile PROFILE ] [ --list-subnets ] [ -h | --help ]

  -t | --type TYPE         EC2 instance type (e.g. t3.medium); supports multi-value in conf
  -o | --owner OWNER       Owner tag value (default: current user)
  -a | --ami AMI           AMI ID or '2023' for latest Amazon Linux 2023 (default: 2023)
  -s | --subnet SUBNET-ID  Subnet ID to launch into (overrides EC_SUBNET_ID / EC_SUBNET_FILTER)
  -v | --vpc VPC-ID        VPC ID to use (overrides EC_VPC_ID / EC_VPC_FILTER)
  -T | --tag Key=Value     Additional tag to apply (may be repeated; appends to EC_EXTRA_TAGS)
  --replace-tags           Replace EC_EXTRA_TAGS entirely with tags from -T flags
  -p | --profile PROFILE   AWS CLI profile to use (overrides EC_AWS_PROFILE)
  --list-subnets           List available subnets matching the current filter and exit
  -h | --help              Show this help
```

Built-in tags applied to all instances and volumes: `Name`, `owner`, `creator`, `project`, `Project`.

### ecSetup

Installs scripts and configures the conf file interactively.

```
Usage: ecSetup [ --configure ] [ --target DIR ] [ -h | --help ]

  --configure    Only review/update the configuration file (no script deployment)
  --target DIR   Install scripts and conf to DIR instead of the default location
  -h | --help    Show this help
```

Default install locations:
- root: scripts → `/usr/local/bin`, config → `/etc/aws-tools/ecTools.conf`
- user: scripts → `~/bin`, config → `~/.config/aws-tools/ecTools.conf`

## Configuration

Both scripts share a single configuration file. The easiest way to set it up:

```bash
./ecSetup
```

Or manually:

```bash
mkdir -p ~/.config/aws-tools
cp ecTools.conf.example ~/.config/aws-tools/ecTools.conf
```

Configuration is loaded in order, with later files taking precedence:

1. `/etc/aws-tools/ecTools.conf` — system-wide defaults
2. `~/.config/aws-tools/ecTools.conf` — user overrides

See `ecTools.conf.example` for all available settings with descriptions.

An optional `ecUserScript` placed alongside the conf file is passed as EC2 user data
on launch. See `ecUserScript.example` for a starting point.

## Requirements

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with valid credentials (IAM user, SSO/Identity Center, or EC2 instance role)
- `bash` 4.0+
- `curl` (for EC2 instance metadata)
- macOS only: `gnu-getopt` — `brew install gnu-getopt`
- SSM mode only: [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)

## License

Copyright (C) 2019 Gil Freund

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, see <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>.
