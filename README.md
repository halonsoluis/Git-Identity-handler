# git-identity

A bash wrapper script for Git that allows you to easily switch between multiple GitHub identities (work and personal) using different SSH keys.

## Features

- Interactive identity selection for each Git operation
- Automatic SSH connection testing
- Support for both work and personal GitHub accounts
- Debug mode for troubleshooting SSH configuration
- Seamless integration with existing Git workflows

## Prerequisites

- Git installed on your system
- SSH keys generated for both work and personal accounts
- SSH config file properly configured

## Installation

### Basic Installation

1. Download the `git-identity` script
2. Make it executable:
   ```bash
   chmod +x git-identity
   ```

### Making it Globally Accessible (Recommended)

To use `git-identity` from anywhere without typing `./`, add it to your PATH:

#### Option 1: System-wide installation (requires sudo)
```bash
sudo cp git-identity /usr/local/bin/
sudo chmod +x /usr/local/bin/git-identity
```

#### Option 2: User-specific installation (no sudo required)
```bash
# Create local bin directory if it doesn't exist
mkdir -p ~/.local/bin

# Copy the script
cp git-identity ~/.local/bin/

# Make sure ~/.local/bin is in your PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### Option 3: Add to existing PATH directory
```bash
# Find directories in your PATH
echo $PATH

# Copy to any existing directory (example with ~/bin)
cp git-identity ~/bin/
chmod +x ~/bin/git-identity
```

### Verification

After installation, verify it works:
```bash
# Check if it's accessible globally
which git-identity

# Test the script
git-identity --help
git-identity --debug
```

### Important Note for Development

When testing script modifications:
- Use `./git-identity` to run the local version
- Use `git-identity` to run the installed version
- Remember to update the installed version after making changes:
  ```bash
  # Update installed version
  sudo cp git-identity /usr/local/bin/  # or wherever you installed it
  ```

## SSH Configuration

Before using this script, you need to set up your SSH configuration file (`~/.ssh/config`):

```ssh
# Work identity (default)
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa

# Personal identity
Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa_personal
    IdentitiesOnly yes
```

### SSH Key Setup

1. **Generate SSH keys** (if you haven't already):
   ```bash
   # Work key (default)
   ssh-keygen -t rsa -b 4096 -C "work@example.com" -f ~/.ssh/id_rsa
   
   # Personal key
   ssh-keygen -t rsa -b 4096 -C "personal@example.com" -f ~/.ssh/id_rsa_personal
   ```

2. **Add public keys to GitHub**:
   - Add `~/.ssh/id_rsa.pub` to your work GitHub account
   - Add `~/.ssh/id_rsa_personal.pub` to your personal GitHub account

3. **Test SSH connections**:
   ```bash
   ssh -T git@github.com          # Should authenticate as work account
   ssh -T git@github-personal     # Should authenticate as personal account
   ```

## Usage

Use `git-identity` exactly like you would use `git`, but you'll be prompted to select which identity to use:

```bash
# Clone a repository
git-identity clone git@github.com:username/repo.git

# Push changes
git-identity push origin main

# Pull changes
git-identity pull origin main

# Any other git command
git-identity status
git-identity commit -m "Your commit message"
```

### Identity Selection

When you run any `git-identity` command, you'll see:

```
Select GitHub identity to use:
1) Work (default ~/.ssh/id_rsa)
2) Personal (github-personal using ~/.ssh/id_rsa_personal)
Enter choice [1-2]:
```

- **Option 1**: Uses your default SSH key for work repositories
- **Option 2**: Uses your personal SSH key and automatically converts `github.com` URLs to `github-personal`

## Examples

### Cloning a Work Repository
```bash
git-identity clone git@github.com:company/work-repo.git
# Select option 1 for work identity
```

### Cloning a Personal Repository
```bash
git-identity clone git@github.com:yourusername/personal-repo.git
# Select option 2 for personal identity
# URL automatically becomes: git@github-personal:yourusername/personal-repo.git
```

### Working with Existing Repositories

For existing repositories, you can use `git-identity` for any operation:

```bash
cd your-repo
git-identity push origin feature-branch
# Select appropriate identity when prompted
```

## Debug Mode

If you're having issues with SSH connections, use the debug mode:

```bash
git-identity --debug
```

This will show:
- SSH config file contents
- Available SSH keys
- Keys loaded in SSH agent

## Troubleshooting

### Common Issues

1. **"Permission denied (publickey)" error**:
   - Verify your SSH keys are added to the correct GitHub accounts
   - Test SSH connections: `ssh -T git@github.com` and `ssh -T git@github-personal`
   - Check if keys are loaded in SSH agent: `ssh-add -l`

2. **"Host github-personal not found" error**:
   - Ensure your `~/.ssh/config` file has the `github-personal` host entry
   - Check file permissions: `chmod 600 ~/.ssh/config`

3. **Script not executing**:
   - Make sure the script is executable: `chmod +x git-identity`
   - Verify bash is available: `which bash`

### Testing SSH Setup

```bash
# Test work identity
ssh -T git@github.com

# Test personal identity
ssh -T git@github-personal

# Expected output format:
# Hi username! You've successfully authenticated, but GitHub does not provide shell access.
```

## Command Reference

```bash
git-identity [git-commands]     # Execute git command with identity selection
git-identity --help            # Show usage information
git-identity --debug           # Show SSH configuration debug info
git-identity -h                # Show usage information
```

## How It Works

1. **Identity Selection**: Script prompts user to choose between work and personal identity
2. **SSH Configuration**: For personal identity, sets `GIT_SSH_COMMAND` and replaces `github.com` with `github-personal`
3. **Connection Testing**: Verifies SSH connection before executing git commands
4. **Git Execution**: Passes all arguments to git with the selected identity configuration

## Security Notes

- SSH keys should have proper permissions (`chmod 600 ~/.ssh/id_rsa*`)
- Use `IdentitiesOnly yes` in SSH config to prevent key guessing
- Consider using SSH agent for better security and convenience

## Contributing

Feel free to submit issues and pull requests to improve this script.

## License

This script is provided as-is for educational and practical use. Feel free to modify and distribute as needed.
