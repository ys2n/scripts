# UVA Library Ansible Scripts

Collection of Ansible playbooks and configurations for managing UVA Library infrastructure.

## Directory Structure

```
ansible/
├── config/                  # Configuration files
│   ├── ansible.cfg         # Main ansible configuration
│   └── inventory.generated # Generated inventory file
├── playbooks/              # Ansible playbooks
│   ├── run_script.yml     # Main script execution playbook
│   └── README.md          # Playbook documentation
├── scripts/                # Executable scripts
│   ├── build-inventory    # Inventory generation script
│   ├── runme.sh          # Host command execution
│   └── remote_script.sh  # Remote script template
└── dev/                    # Development and testing
    ├── run_script_debug.yml
    ├── run_script_debug2.yml
    └── run_script_debug3.yml
```

## Available Scripts

### Infrastructure Management
- `scripts/build-inventory` - Generates Ansible inventory from Terraform infrastructure
- `scripts/runme.sh` - Basic host command execution example

### Remote Execution
- `scripts/remote_script.sh` - Template for remote script execution

## Playbooks

### Production Playbooks
- `playbooks/run_script.yml` - Main playbook for executing scripts across hosts

### Configuration
- `config/ansible.cfg` - Core Ansible settings
- `config/inventory.generated` - Current infrastructure inventory

## Usage Examples

### Running Scripts on All Hosts
```bash
ansible-playbook playbooks/run_script.yml
```

### Generating New Inventory
```bash
./scripts/build-inventory > config/inventory.generated
```

### Testing Host Connectivity
```bash
ansible all -m ping
```
