#!/bin/bash
#
# git-identity-setup - Setup script for git-identity
#
# This script helps configure SSH keys and settings required for git-identity
#
# Usage: ./git-identity-setup
#
# Author: AI Assistant

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo -e "\n${BOLD}=== $1 ===${NC}\n"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate email format
validate_email() {
    local email="$1"
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to create SSH key
create_ssh_key() {
    local key_name="$1"
    local email="$2"
    local key_path="$HOME/.ssh/${key_name}"
    
    if [[ -f "$key_path" ]]; then
        print_warning "SSH key $key_path already exists"
        read -p "Overwrite existing key? (y/N): " overwrite
        if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
            print_info "Skipping key creation for $key_name"
            return 0
        fi
    fi
    
    print_info "Creating SSH key: $key_path"
    ssh-keygen -t rsa -b 4096 -C "$email" -f "$key_path" -N ""
    
    if [[ -f "$key_path" ]]; then
        print_success "SSH key created: $key_path"
        chmod 600 "$key_path"
        chmod 644 "${key_path}.pub"
        return 0
    else
        print_error "Failed to create SSH key: $key_path"
        return 1
    fi
}

# Function to create SSH config
create_ssh_config() {
    local config_file="$HOME/.ssh/config"
    local backup_file="$HOME/.ssh/config.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    # Backup existing config if it exists
    if [[ -f "$config_file" ]]; then
        print_info "Backing up existing SSH config to $backup_file"
        cp "$config_file" "$backup_file"
    fi
    
    # Check if git-identity config already exists
    if [[ -f "$config_file" ]] && grep -q "# git-identity configuration" "$config_file"; then
        print_warning "git-identity configuration already exists in SSH config"
        read -p "Update existing configuration? (y/N): " update_config
        if [[ "$update_config" != "y" && "$update_config" != "Y" ]]; then
            print_info "Skipping SSH config update"
            return 0
        fi
        
        # Remove existing git-identity configuration
        sed -i.tmp '/# git-identity configuration/,/# End git-identity configuration/d' "$config_file"
        rm -f "${config_file}.tmp"
    fi
    
    # Add git-identity configuration
    cat >> "$config_file" << EOF

# git-identity configuration
# Work identity (default)
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes

# Personal identity
Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa_personal
    IdentitiesOnly yes
# End git-identity configuration
EOF
    
    chmod 600 "$config_file"
    print_success "SSH config updated: $config_file"
}

# Function to display public key
display_public_key() {
    local key_name="$1"
    local key_type="$2"
    local key_path="$HOME/.ssh/${key_name}.pub"
    
    if [[ ! -f "$key_path" ]]; then
        print_error "Public key not found: $key_path"
        return 1
    fi
    
    print_header "$key_type SSH Public Key"
    echo -e "${BOLD}File:${NC} $key_path"
    echo -e "${BOLD}Content:${NC}"
    echo
    cat "$key_path"
    echo
    
    print_info "Copy the above key and add it to your GitHub account:"
    if [[ "$key_type" == "Work" ]]; then
        echo -e "${BOLD}GitHub Settings:${NC} https://github.com/settings/ssh/new"
    else
        echo -e "${BOLD}GitHub Settings:${NC} https://github.com/settings/ssh/new"
    fi
    echo
    
    read -p "Press Enter to continue..."
}

# Function to test SSH connections
test_ssh_connections() {
    print_header "Testing SSH Connections"
    
    print_info "Testing work identity (github.com)..."
    local work_output
    
    # Use a more robust timeout and non-interactive approach
    if command -v timeout >/dev/null 2>&1; then
        work_output=$(timeout 15 ssh -T -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes -o PasswordAuthentication=no git@github.com 2>&1 || true)
    else
        # Fallback for systems without timeout command
        work_output=$(ssh -T -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes -o PasswordAuthentication=no git@github.com 2>&1 || true)
    fi
    
    local work_exit_code=$?
    
    if [[ -n "$work_output" ]]; then
        echo -e "${BLUE}Debug output:${NC} $work_output"
    else
        echo -e "${BLUE}Debug output:${NC} (no output - connection may have timed out)"
    fi
    
    if echo "$work_output" | grep -q "successfully authenticated"; then
        print_success "Work identity connection successful"
        if echo "$work_output" | grep -q "Hi "; then
            local username=$(echo "$work_output" | sed -n 's/Hi \([^!]*\)!.*/\1/p')
            print_info "Authenticated as: $username"
        fi
    elif echo "$work_output" | grep -q "Permission denied"; then
        print_warning "Work identity authentication failed - check if SSH key is added to GitHub"
    elif echo "$work_output" | grep -q "Connection timed out\|timeout"; then
        print_warning "Work identity connection timed out - check network connectivity"
    else
        print_warning "Work identity connection failed (exit code: $work_exit_code)"
        if [[ -n "$work_output" ]]; then
            print_info "Raw output: $work_output"
        fi
    fi
    
    echo
    print_info "Testing personal identity (github-personal)..."
    local personal_output
    
    if command -v timeout >/dev/null 2>&1; then
        personal_output=$(timeout 15 ssh -T -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes -o PasswordAuthentication=no git@github-personal 2>&1 || true)
    else
        personal_output=$(ssh -T -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes -o PasswordAuthentication=no git@github-personal 2>&1 || true)
    fi
    
    local personal_exit_code=$?
    
    if [[ -n "$personal_output" ]]; then
        echo -e "${BLUE}Debug output:${NC} $personal_output"
    else
        echo -e "${BLUE}Debug output:${NC} (no output - connection may have timed out)"
    fi
    
    if echo "$personal_output" | grep -q "successfully authenticated"; then
        print_success "Personal identity connection successful"
        if echo "$personal_output" | grep -q "Hi "; then
            local username=$(echo "$personal_output" | sed -n 's/Hi \([^!]*\)!.*/\1/p')
            print_info "Authenticated as: $username"
        fi
    elif echo "$personal_output" | grep -q "Permission denied"; then
        print_warning "Personal identity authentication failed - check if SSH key is added to GitHub"
    elif echo "$personal_output" | grep -q "Connection timed out\|timeout"; then
        print_warning "Personal identity connection timed out - check network connectivity"
    elif echo "$personal_output" | grep -q "Could not resolve hostname"; then
        print_warning "Personal identity hostname resolution failed - check SSH config"
    else
        print_warning "Personal identity connection failed (exit code: $personal_exit_code)"
        if [[ -n "$personal_output" ]]; then
            print_info "Raw output: $personal_output"
        fi
    fi
    
    echo
    print_info "Manual testing commands:"
    echo "  ssh -T git@github.com"
    echo "  ssh -T git@github-personal"
    echo
    print_info "To skip SSH testing in future runs, you can check connections manually"
}

# Function to show final instructions
show_final_instructions() {
    print_header "Setup Complete!"
    
    echo -e "${BOLD}What was configured:${NC}"
    echo "• SSH keys created: ~/.ssh/id_rsa and ~/.ssh/id_rsa_personal"
    echo "• SSH config updated: ~/.ssh/config"
    echo
    
    echo -e "${BOLD}Next steps:${NC}"
    echo "1. Add both SSH public keys to your respective GitHub accounts"
    echo "2. Test the setup by running: git-identity --debug"
    echo "3. Start using git-identity for your Git operations"
    echo
    
    echo -e "${BOLD}Usage examples:${NC}"
    echo "• git-identity clone git@github.com:username/repo.git"
    echo "• git-identity push origin main"
    echo "• git-identity pull origin main"
    echo
    
    print_info "Run 'git-identity --help' for more information"
}

# Main setup function
main() {
    print_header "git-identity Setup Script"
    
    # Check prerequisites
    if ! command_exists ssh-keygen; then
        print_error "ssh-keygen not found. Please install OpenSSH client."
        exit 1
    fi
    
    if ! command_exists git; then
        print_error "git not found. Please install Git."
        exit 1
    fi
    
    # Get email addresses
    print_header "Email Configuration"
    
    while true; do
        read -p "Enter your WORK email address: " work_email
        if validate_email "$work_email"; then
            break
        else
            print_error "Invalid email format. Please try again."
        fi
    done
    
    while true; do
        read -p "Enter your PERSONAL email address: " personal_email
        if validate_email "$personal_email"; then
            break
        else
            print_error "Invalid email format. Please try again."
        fi
    done
    
    print_info "Work email: $work_email"
    print_info "Personal email: $personal_email"
    echo
    
    # Create SSH keys
    print_header "Creating SSH Keys"
    
    if ! create_ssh_key "id_rsa" "$work_email"; then
        print_error "Failed to create work SSH key"
        exit 1
    fi
    
    if ! create_ssh_key "id_rsa_personal" "$personal_email"; then
        print_error "Failed to create personal SSH key"
        exit 1
    fi
    
    # Create SSH config
    print_header "Configuring SSH"
    create_ssh_config
    
    # Display public keys
    print_header "SSH Public Keys"
    print_info "You need to add these public keys to your GitHub accounts"
    echo
    
    display_public_key "id_rsa" "Work"
    display_public_key "id_rsa_personal" "Personal"
    
    # Ask if user wants to test connections
    read -p "Do you want to test SSH connections now? (y/N): " test_now
    if [[ "$test_now" == "y" || "$test_now" == "Y" ]]; then
        test_ssh_connections
    else
        print_info "You can test connections later with: git-identity --debug"
    fi
    
    # Show final instructions
    show_final_instructions
}

# Show help
show_help() {
    echo "git-identity-setup - Setup script for git-identity"
    echo
    echo "This script helps you configure SSH keys and settings for git-identity."
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --test-only    Only test existing SSH connections"
    echo "  --show-keys    Display existing public keys"
    echo
    echo "What this script does:"
    echo "1. Creates SSH keys for work and personal GitHub accounts"
    echo "2. Configures SSH config file with proper settings"
    echo "3. Displays public keys for easy copying to GitHub"
    echo "4. Tests SSH connections (optional)"
    echo
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --test-only)
        test_ssh_connections
        exit 0
        ;;
    --show-keys)
        print_header "Existing SSH Public Keys"
        if [[ -f "$HOME/.ssh/id_rsa.pub" ]]; then
            display_public_key "id_rsa" "Work"
        else
            print_warning "Work key not found: $HOME/.ssh/id_rsa.pub"
        fi
        
        if [[ -f "$HOME/.ssh/id_rsa_personal.pub" ]]; then
            display_public_key "id_rsa_personal" "Personal"
        else
            print_warning "Personal key not found: $HOME/.ssh/id_rsa_personal.pub"
        fi
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac