# WordPress Migration Orchestrator

Complete automated WordPress migration workflow manager for K3s/Kubernetes environments. This orchestrator coordinates all migration components to provide a seamless end-to-end migration experience.

## 🎯 Overview

The orchestrator manages the complete WordPress migration pipeline with five integrated components:

1. **migrate.py** - Source WordPress site backup with browser automation
2. **k3s-wp-spawner.sh** - K3s WordPress deployment with persistent storage  
3. **setup-wordpress-admin.sh** - Automated WordPress configuration and plugin setup
4. **import.py** - Backup import with upload limit management
5. **update-htaccess.sh** - PHP upload limit management for large files

## ✨ Key Features

✅ **🔄 End-to-End Automation** - Complete migration in a single command  
✅ **🎯 Interactive Configuration** - Guided setup with intelligent defaults  
✅ **📤 Smart Upload Management** - Dynamic PHP limits (2M → 128M → 2M)  
✅ **🔒 Secure by Default** - Auto-generated passwords and secure configurations  
✅ **🛡️ Robust Error Handling** - Comprehensive validation and rollback capabilities  
✅ **📊 Real-time Progress** - Color-coded output with detailed status updates  
✅ **🧹 Automatic Cleanup** - Temporary file management and resource optimization  
✅ **☸️ K3s Optimized** - Designed for low-resource Kubernetes environments  

## 📋 Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04+ or compatible Linux distribution
- **RAM**: 2GB minimum, 4GB recommended
- **Storage**: 20GB+ available space
- **Network**: Internet connectivity for package downloads

### Software Dependencies
```bash
# Core requirements
- Python 3.10+
- K3s/Kubernetes with kubectl access
- Bash shell environment
- curl and wget utilities

# Python packages (auto-installed)
- playwright
- beautifulsoup4  
- requests
```

### Kubernetes Environment
- **K3s cluster** with Traefik ingress controller
- **kubectl** configured with cluster access
- **Persistent volume** support (local-path provisioner)
- **Network policies** allowing HTTP traffic

## 📁 Project Structure

Complete project layout with all migration components:
```
wp_migration_tool/
├── 🎯 wp-migration-orchestrator.sh    # Main orchestration workflow
├── 🔄 migrate.py                      # Source backup automation
├── 📥 import.py                       # Target import automation  
├── ☸️ k3s-wp-spawner.sh               # K3s deployment script
├── 🔧 setup-wordpress-admin.sh        # WordPress admin setup
├── 📤 update-htaccess.sh              # Upload limit management
├── ✅ check-prerequisites.sh          # Environment validation
├── 🧪 test-environment.sh             # System testing
├── 📋 test-orchestrator.sh           # Orchestrator testing
├── 🪟 run-migration.bat              # Windows wrapper
├── 📂 templates/                      # Kubernetes manifests
│   ├── wordpress-limit-job.yaml
│   ├── wp-configmap.yaml
│   ├── wp-secret.yaml
│   └── wp-service.yaml
├── 📄 README.md                      # Main project documentation
├── 📄 ORCHESTRATOR_README.md         # This orchestrator guide
├── 📄 PROJECT_SUMMARY.md             # Project overview
└── 📄 SETUP_COMPLETE.md              # Setup completion guide
```

## 🚀 Usage Guide

### Quick Start
```bash
# 1. Validate environment
./check-prerequisites.sh

# 2. Run complete migration
./wp-migration-orchestrator.sh
```

### Advanced Usage
```bash
# Test orchestrator without running migration
./test-orchestrator.sh

# Test individual environment components
./test-environment.sh

# Manual component execution
python3 migrate.py              # Backup only
./k3s-wp-spawner.sh domain.com ns     # Deploy only  
python3 import.py               # Import only
```

### Windows Environment
```bash
# Use the provided batch wrapper
run-migration.bat

# Or run directly in WSL
wsl ./wp-migration-orchestrator.sh
```

## 📊 Interactive Workflow

The orchestrator manages a comprehensive 5-phase migration process:

### 🔄 Phase 1: Source Site Backup
- 📝 Interactive source WordPress URL and credential collection
- 🔌 Automatic All-in-One WP Migration plugin installation/activation
- 🤖 Headless browser automation for backup creation
- 📁 Organized backup file storage with site-specific folders

### ☸️ Phase 2: K3s WordPress Deployment  
- 🎯 Interactive target domain and namespace configuration
- 🗄️ MariaDB deployment with persistent storage (5Gi)
- 🐘 WordPress deployment with optimized resource limits
- 🌐 Traefik ingress configuration for HTTP access
- 🔐 Auto-generated secure database and admin credentials

### 🔧 Phase 3: WordPress Admin Setup
- 🛠️ Automated WordPress core installation and configuration
- 👤 Admin user creation with secure credentials
- 🔌 All-in-One WP Migration plugin installation via WP-CLI
- 📁 File permission optimization for WordPress security

### 📤 Phase 4: Upload Limit Management & Import
- ⚙️ Dynamic PHP upload limit adjustment (2M → 128M)
- 🚀 Automated backup upload to target WordPress site
- 🔄 Plugin-based import process with progress monitoring
- ✅ Import completion verification and error handling

### 🔒 Phase 5: Security & Cleanup
- 📉 Upload limit restoration to secure defaults (128M → 2M) 
- 🧹 Temporary file cleanup and resource optimization
- 📋 Deployment summary with access credentials
- 🎯 Final verification and handoff information

## 💻 Example Migration Session

```bash
$ ./wp-migration-orchestrator.sh

===========================================
WordPress Migration Orchestrator  
===========================================

ℹ️  This script will:
ℹ️  1. Backup your source WordPress site
ℹ️  2. Deploy a new WordPress instance on K3s
ℹ️  3. Import the backup to the new instance

===========================================
MIGRATION CONFIGURATION
===========================================

ℹ️  Source Site Information:
Enter source WordPress URL: http://old-site.example.com
Enter admin username: admin
Enter admin password: [hidden]

ℹ️  Target Site Information:
Enter new domain: new-site.example.com  
Enter Kubernetes namespace: my-wp-site
Enter admin email: admin@example.com

===========================================
PHASE 1: SOURCE SITE BACKUP
===========================================

ℹ️  Starting backup process...
✅ Login successful
✅ Plugin installed and activated
✅ Backup created: /home/ubuntu/backup-receiver/old_site_example_com/backup.wpress

===========================================
PHASE 2: K3S WORDPRESS DEPLOYMENT
===========================================

ℹ️  Deploying WordPress on K3s...
✅ Namespace created: my-wp-site
✅ MariaDB deployed and ready
✅ WordPress deployed and ready
✅ Ingress configured for new-site.example.com

===========================================
WordPress Migration Orchestrator
===========================================

ℹ️  This script will:
ℹ️  1. Backup your source WordPress site
ℹ️  2. Deploy a new WordPress instance on Kubernetes
ℹ️  3. Import the backup to the new instance

===========================================
PHASE 1: SOURCE SITE BACKUP
===========================================

Enter source WordPress URL (e.g., https://old-site.com): https://myoldsite.com
Enter source WordPress admin username: admin
Enter source WordPress admin password: [hidden]

ℹ️  Updating migrate.py configuration...
ℹ️  Starting backup process...
   -> Login successful.
   -> Plugin is already ACTIVE. Proceeding to export.
   ✅ Backup file saved to EC2 at: /home/ubuntu/backup-receiver/recieved_wp/myoldsite_com/myoldsite-20241008-143022-abc123.wpress
✅ Backup completed successfully!

===========================================
PHASE 2: DEPLOY NEW WORDPRESS INSTANCE
===========================================

--- Client WordPress Deployment Setup ---
Enter Client Namespace (e.g., client-a): client-migration
Enter DB Name (e.g., client_a_wp_db): migration_wp_db
Enter DB User (e.g., wp_client_a_user): wp_migration_user
Enter WP DB Password: [hidden]
Enter MySQL ROOT Password: [hidden]

✅ Deployment for client 'client-migration' is complete!

[... continues through all phases ...]

===========================================
MIGRATION COMPLETE!
===========================================

✅ WordPress migration completed successfully!
ℹ️  Source site: https://myoldsite.com
ℹ️  Target site: https://mynewsite.com
ℹ️  Kubernetes namespace: client-migration
ℹ️  You can now access your migrated site at: https://mynewsite.com

🎉 Migration orchestration completed successfully!
```

## Troubleshooting

### Common Issues

**Script not executable:**
```bash
chmod +x wp-migration-orchestrator.sh
```

**Python dependencies missing:**
```bash
pip install playwright
playwright install
```

**Kubernetes access issues:**
```bash
kubectl cluster-info
kubectl get nodes
```

**WordPress not ready:**
- Check pod status: `kubectl get pods -n [namespace]`
- Check services: `kubectl get svc -n [namespace]`
- Check logs: `kubectl logs -n [namespace] [pod-name]`

### File Upload Issues

If imports fail due to upload limits:
- The script automatically manages .htaccess files
- Manual recovery: Check `/var/www/html/.htaccess.backup` in WordPress pod
- Verify PHP settings in WordPress container

### Backup File Issues

If backup files aren't found:
- Check `/home/ubuntu/backup-receiver/recieved_wp/[site-folder]/`
- Verify migrate.py completed successfully
- Check disk space on backup server

## Security Considerations

- Passwords are handled securely (hidden input)
- Temporary files are automatically cleaned up
- Original .htaccess files are backed up before modification
- No credentials are stored permanently in scripts

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review individual script logs (migrate.py, import.py output)
3. Verify Kubernetes cluster status
4. Check WordPress pod logs for application-level issues

## Authors

- [@ajith4Tech](https://www.github.com/ajith4Tech)