# Security Policy

This repository contains formal models and CI/Codespaces configuration. It should not contain secrets.

## Reporting

Use GitHub private vulnerability reporting if it is available on the repository. Otherwise, open a private channel with the repository owner before publishing security-sensitive findings.

## Security Automation

The repository is configured for:

- GitHub Advanced Security settings where available.
- CodeQL analysis for GitHub Actions workflows.
- Dependabot updates for GitHub Actions and devcontainer dependencies.
- Secret scanning and push protection where the GitHub plan/repository visibility supports them.
