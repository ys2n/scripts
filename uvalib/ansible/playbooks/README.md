# Ansible Playbooks

## Production Playbooks

### run_script.yml
- Main playbook for executing scripts across hosts
- Supports gathering and combining results
- JSON output format

### run_script_final.yml  
- Alternative implementation with improved error handling
- Uses centralized results collection
- Supports partial failure recovery
