# aws-tools

Bash scripts for connecting to and launching EC2 instances.

## Scripts

### ecConnect

Interactively lists running EC2 instances filtered by tag and opens an SSH session.

```
Usage: ecConnect [ -L | --forward SPEC ] [ -f | --fork ] [ -u | --user USER ] [ -h | --help ]
                 [ public | private ] [ random | i-<id> | <number> | list ]

  -L | --forward SPEC   SSH port forward, e.g. 8080:localhost:80 (may be repeated)
  -f | --fork           Fork SSH into background (-f -N, tunnel only)
  -u | --user USER      SSH username (overrides EC_SSH_USER from config)
  -h | --help           Show this help
  public | private      Override EC_IP_CONNECTION from config
  random                Connect to a random matching instance
  i-<id>                Connect to a specific instance by ID
  <number>              Connect to instance by list position
  list                  Print matching instances and exit
```

### ecLaunch

Launches a new EC2 instance using a launch template, with automatic AMI selection based on instance type architecture and accelerator.

```
Usage: ecLaunch [ -t | --type TYPE ] [ -o | --owner OWNER ] [ -p | --project PROJECT ]
                [ -a | --ami AMI ] [ -h | --help ]

  -t | --type TYPE      EC2 instance type (e.g. t3.medium)
  -o | --owner OWNER    Owner tag value (default: current user)
  -p | --project NAME   Project tag value (required)
  -a | --ami AMI        AMI ID or '2023' for latest Amazon Linux 2023 (default: 2023)
  -h | --help           Show this help
```

## Configuration

Both scripts share a single configuration file. Copy the example and fill in your values:

```bash
mkdir -p ~/.config/aws-tools
cp aws-tools.conf.example ~/.config/aws-tools/aws-tools.conf
```

Configuration is loaded in order, with later files taking precedence:

1. `/etc/aws-tools/aws-tools.conf` — system-wide defaults
2. `~/.config/aws-tools/aws-tools.conf` — user overrides

See `aws-tools.conf.example` for all available settings with descriptions.

## Requirements

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with valid credentials (IAM user, SSO/Identity Center, or EC2 instance role)
- `bash` 4.0+
- `curl` (for EC2 instance metadata)
- macOS only: `gnu-getopt` — `brew install gnu-getopt`

## License

Copyright (C) 2019 Gil Freund

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, see <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>.
