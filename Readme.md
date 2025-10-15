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
- **🎯 Interactive Setup**: Guided configuration with progress indicators
- **🔒 Secure Credentials**: Auto-generated passwords and secure storage
- **📊 Resource Optimization**: Optimized for low-resource environments

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
```bash
# Interactive migration workflow
./wp-migration-orchestrator.sh
```

### 3. Test Environment
```bash
# Validate setup before migration
./test-environment.sh
```

## 📖 Migration Workflow

### Phase 1: Source Site Backup
- 🔐 Interactive credential collection for source WordPress site
- 🔌 Automatic All-in-One WP Migration plugin installation/activation
- 🤖 Headless browser automation for backup creation
- 📁 Organized backup file storage in `/home/ubuntu/backup-receiver/`

### Phase 2: K3s Deployment
- 🎯 Interactive domain and namespace configuration  
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
├── 🎯 wp-migration-orchestrator.sh    # Main orchestration workflow
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
```bash
# Full automated migration
./wp-migration-orchestrator.sh
# Follow interactive prompts for:
# - Source site URL and credentials
# - Target domain and namespace
# - Admin email configuration
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

## 🐛 Troubleshooting

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

---
**Last Updated**: October 2025  
**Version**: 2.0.0  
**Tested On**: Ubuntu 22.04, K3s v1.33.5+k3s1
kubectl cluster-info
kubectl get nodes
```


