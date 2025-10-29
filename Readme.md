# WordPress Migration Tool

Complete automated WordPress migration solution for K3s/Kubernetes environments. This tool orchestrates the entire migration workflow from source site backup to target site deployment and import.

## 🚀 Overview

This tool automates WordPress migration with these key components:

1. **migrate.py** - Creates backup of source WordPress site using browser automation
2. **k3s-wp-spawner.sh** - Deploys new WordPress instance on K3s/Kubernetes
3. **import.py** - Imports backup to target site with automatic upload limit management
4. **wp-migration-orchestrator.sh** - Main orchestrator that runs the complete workflow
5. **setup-wordpress-admin.sh** - Automated WordPress admin setup and plugin installation

## ✨ Features

- **🔄 Complete Workflow Automation**: Single command migration from source to target
- **🤖 Browser Automation**: Headless Playwright automation for WordPress operations
- **☸️ Kubernetes Native**: Built for K3s/Kubernetes environments
- **📦 Plugin Management**: Automatic All-in-One WP Migration plugin installation
- **📁 Upload Limit Handling**: Dynamic PHP upload limits for large backup files
- **🎯 Dual Mode Operation**: Interactive setup or non-interactive automation
- **🔧 Command Line Interface**: Full CLI support for automation and scripting
- **🔒 Secure Credentials**: Auto-generated passwords and secure storage
- **📊 Resource Optimization**: Optimized for low-resource environments
- **🚀 CI/CD Ready**: Perfect for automated deployment pipelines

## 📋 Prerequisites

- **Python 3.10+** with pip
- **K3s/Kubernetes** cluster with kubectl access
- **Traefik ingress** (automatically configured with K3s)
- **Internet connection** for package downloads
- **Domain/subdomain** for target WordPress site

### System Requirements
- 2GB+ RAM (4GB recommended)
- 20GB+ disk space
- Ubuntu 20.04+ or similar Linux distribution

## 🚀 Quick Start

### 1. Setup Environment
```bash
# Check prerequisites
./check-prerequisites.sh

# Install dependencies (if needed)
pip3 install playwright beautifulsoup4 requests
playwright install chromium
```

### 2. Run Complete Migration

#### Interactive Mode (Guided Setup)
```bash
# Interactive migration workflow with prompts
./wp-migration-orchestrator.sh
```

#### Non-Interactive Mode (Automation Ready)
```bash
# Minimal - with auto-generated defaults
./wp-migration-orchestrator.sh -u https://old-site.com -n admin -p password123

# Complete - with custom parameters
./wp-migration-orchestrator.sh \
  -u https://old-site.com \
  -n admin \
  -p password123 \
  -d new-site.test.kunj.company \
  -s wp-client-prod \
  -e admin@newsite.com
```

### 3. Test Environment
```bash
# Validate setup before migration
./test-environment.sh
```

## 📖 Migration Workflow

### Phase 1: Source Site Backup
- 🔐 Credential collection (interactive prompts or CLI parameters)
- 🔌 Automatic All-in-One WP Migration plugin installation/activation
- 🤖 Headless browser automation for backup creation
- 📁 Organized backup file storage in `/home/ubuntu/backup-receiver/`

### Phase 2: K3s Deployment
- 🎯 Domain and namespace configuration (interactive or auto-generated)
- 🗄️ MariaDB database with persistent storage
- 🐘 WordPress deployment with resource optimization
- 🌐 Traefik ingress configuration for HTTP access
- 🔧 Auto-generated secure credentials

### Phase 3: WordPress Setup
- 🔧 Automated admin user creation via WP-CLI
- 🔌 All-in-One WP Migration plugin installation
- 📁 File permission configuration for WordPress security
- ⚙️ PHP upload limit adjustment for large backups

### Phase 4: Backup Import
- 📤 Automated backup upload to target site
- 🔄 Plugin-based import process via browser automation
- 📊 Progress monitoring and error handling
- ✅ Import verification and completion

### Phase 5: Finalization
- 🔒 Upload limit restoration to secure defaults
- 🧹 Temporary file cleanup
- 📋 Deployment summary and access information

## 📁 Project Structure

```
wp_migration_tool/
├── 🎯 wp-migration-orchestrator.sh    # Main orchestrator (Interactive + CLI)
├── 🔄 migrate.py                      # Source site backup automation  
├── 📥 import.py                       # Target site import automation
├── ☸️ k3s-wp-spawner.sh               # K3s WordPress deployment
├── 🔧 setup-wordpress-admin.sh        # WordPress admin setup
├── 📤 update-htaccess.sh              # Upload limit management
├── ✅ check-prerequisites.sh          # Environment validation
├── 🧪 test-environment.sh             # Setup testing
├── 🪟 run-migration.bat              # Windows wrapper script
├── 📋 test-orchestrator.sh           # Orchestrator testing
├── 📂 templates/                      # Kubernetes YAML templates
└── 📄 *.md                           # Documentation files
```

## 🔧 Usage Examples

### Complete Migration

#### Interactive Mode
```bash
# Full guided migration with interactive prompts
./wp-migration-orchestrator.sh
# Follow prompts for:
# - Source site URL and credentials
# - Target domain and namespace (with smart defaults)
# - Admin email configuration
```

#### Non-Interactive Mode
```bash
# Show help and available options
./wp-migration-orchestrator.sh --help

# Minimal migration with auto-generated defaults
./wp-migration-orchestrator.sh \
  --url https://source-site.com \
  --username admin \
  --password mypassword

# Full migration with custom parameters
./wp-migration-orchestrator.sh \
  --url https://source-site.com \
  --username admin \
  --password mypassword \
  --domain new-site.test.kunj.company \
  --namespace wp-production \
  --email admin@company.com

# Short form arguments
./wp-migration-orchestrator.sh \
  -u https://source-site.com \
  -n admin \
  -p mypassword \
  -d new-site.test.kunj.company \
  -s wp-prod \
  -e admin@company.com
```

#### Automation & Scripting
```bash
# Use in CI/CD pipelines
#!/bin/bash
SOURCE_URL="https://staging.mysite.com"
ADMIN_USER="admin"
ADMIN_PASS="${WP_ADMIN_PASSWORD}"  # From environment variable
TARGET_DOMAIN="production.mysite.com"

./wp-migration-orchestrator.sh \
  -u "$SOURCE_URL" \
  -n "$ADMIN_USER" \
  -p "$ADMIN_PASS" \
  -d "$TARGET_DOMAIN" \
  -s wp-production \
  -e ops@company.com
```

### Individual Components
```bash
# Only create backup
python3 migrate.py

# Only deploy K3s WordPress
./k3s-wp-spawner.sh new-site.example.com my-namespace

# Only import backup
python3 import.py

# Only setup WordPress admin
./setup-wordpress-admin.sh
```

## � Command Line Reference

### wp-migration-orchestrator.sh Options

```bash
Usage: ./wp-migration-orchestrator.sh [OPTIONS]

OPTIONS:
  -u, --url <URL>           Source WordPress URL (required for non-interactive mode)
  -n, --username <USER>     Source WordPress admin username (required for non-interactive mode)
  -p, --password <PASS>     Source WordPress admin password (required for non-interactive mode)
  -d, --domain <DOMAIN>     New domain for migrated site (optional, defaults to auto-generated)
  -s, --namespace <NS>      Kubernetes namespace (optional, defaults to auto-generated)
  -e, --email <EMAIL>       Admin email (optional, defaults to admin@example.com)
  -h, --help               Show help message
```

### Default Values
When using non-interactive mode, optional parameters use these defaults:
- **Domain**: `wp-migrated-[timestamp].test.kunj.company`
- **Namespace**: `wp-migration-[6-digit-timestamp]`
- **Email**: `admin@example.com`

### Mode Detection
- **Interactive Mode**: Triggered when no parameters are provided
- **Non-Interactive Mode**: Triggered when `-u`, `-n`, and `-p` are all provided
- **Mixed Mode**: Not supported - either provide all required params or none

## �🐛 Troubleshooting

### Python/Playwright Issues
```bash
# Reinstall Python environment
rm -rf wp_migration_venv
./check-prerequisites.sh
```

### Kubernetes Issues
```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Debug WordPress deployment
kubectl describe pod <wordpress-pod-name> -n <namespace>
kubectl logs <wordpress-pod-name> -n <namespace>

# Clean up failed deployment
kubectl delete namespace <namespace-name>
```

### WordPress Plugin Issues
```bash
# Manual plugin installation
kubectl exec -it <wordpress-pod> -n <namespace> -- wp plugin install all-in-one-wp-migration --activate

# Check file permissions
kubectl exec -it <wordpress-pod> -n <namespace> -- ls -la /var/www/html/
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🙏 Acknowledgments

- WordPress community for excellent documentation
- Kubernetes/K3s teams for container orchestration
- Playwright team for reliable browser automation
- All-in-One WP Migration plugin developers

## 📞 Support

For issues and questions:
- Create an issue in the GitHub repository
- Check existing documentation in the `*.md` files
- Review troubleshooting section above

## 🚀 Quick Examples

### For Manual Migrations
```bash
# Interactive setup - best for first-time users
./wp-migration-orchestrator.sh
```

### For Automation
```bash
# Basic automation - auto-generated target
./wp-migration-orchestrator.sh -u https://source.com -n admin -p pass123

# Production deployment - custom target
./wp-migration-orchestrator.sh \
  -u https://staging.mysite.com \
  -n admin \
  -p $WP_PASSWORD \
  -d production.mysite.com \
  -s wp-prod \
  -e ops@mysite.com
```

### For Testing
```bash
# Quick test migration with defaults
./wp-migration-orchestrator.sh \
  -u https://demo.wordpress.com \
  -n demo \
  -p demo123
```

---
**Last Updated**: October 2025  
**Version**: 2.1.0 - Added CLI Support  
**Tested On**: Ubuntu 22.04, K3s v1.33.5+k3s1


