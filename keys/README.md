# SSH Keys Directory

This directory contains SSH public keys used for server bootstrapping.

## Required Files

- `admin_key.pub` - Your personal SSH public key (for root and ubuntu user)
- `github_actions_key.pub` - GitHub Actions SSH public key (for ubuntu user only)

## Usage

1. Place your SSH public keys in this directory
2. Run the bootstrap playbook: `ansible-playbook -i <host>, bootstrap.yaml --ask-pass`

Note: Use `--ask-pass` on first run since the server only has root password authentication initially.

## Security

- Only `.pub` (public key) files should be stored here
- Never commit private keys to this repository
- Private keys are already ignored by .gitignore
