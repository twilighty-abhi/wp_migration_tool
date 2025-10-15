# Kubernetes Templates Directory

This directory contains Kubernetes YAML manifests for WordPress deployment infrastructure. These templates are used by the deployment scripts to create WordPress instances on K3s/Kubernetes clusters.

## 📁 Template Files

### 🗄️ Database Components
- **mysql-service.yaml** - MariaDB service definition for WordPress database connectivity
- **mysql-statefulset.yaml** - MariaDB StatefulSet with persistent storage configuration

### 🐘 WordPress Components  
- **wordpress-deployment.yaml** - WordPress application deployment with resource limits
- **wp-service.yaml** - WordPress service definition for internal cluster communication
- **wp-configmap.yaml** - WordPress configuration data (environment variables)
- **wp-secret.yaml** - Secure credential storage for database passwords

### 🔧 Utility Components
- **wordpress-limit-job.yaml** - Kubernetes Job for PHP upload limit management
- **.htaccess** - Apache configuration template for WordPress optimization

## 🎯 Usage

These templates are automatically used by:

- **k3s-wp-spawner.sh** - Primary K3s deployment script
- **deploy-client.sh** - Legacy Kubernetes deployment script  
- **wp-migration-orchestrator.sh** - Main orchestrator workflow

## 📋 Template Features

### 🔒 Security
- Secret-based credential management
- Secure environment variable injection
- Non-root container execution where possible

### 💾 Storage
- Persistent Volume Claims for data persistence
- Separate storage for WordPress files and database
- Local-path provisioner compatibility (K3s default)

### 📊 Resource Management
- CPU and memory limits for containers
- Resource requests for scheduling optimization
- Health checks with readiness/liveness probes

### 🌐 Networking
- Service-based internal communication
- Ingress-ready service configurations
- Port standardization (WordPress: 80, MariaDB: 3306)

## 🔧 Customization

To customize WordPress deployments:

1. **Resource Limits**: Modify `resources` sections in deployment files
2. **Storage Size**: Adjust `storage` requests in PVC definitions
3. **Environment Variables**: Update ConfigMap and Secret templates
4. **Image Versions**: Change container image tags as needed

### Example Resource Customization
```yaml
resources:
  requests:
    memory: "256Mi"    # Increase for high-traffic sites
    cpu: "200m"
  limits:
    memory: "512Mi"    # Adjust based on available resources
    cpu: "500m"
```

### Example Storage Customization  
```yaml
spec:
  resources:
    requests:
      storage: 20Gi    # Increase for larger WordPress sites
```

## 🧪 Testing Templates

Validate template syntax:
```bash
# Test individual templates
kubectl apply --dry-run=client -f mysql-service.yaml
kubectl apply --dry-run=client -f wordpress-deployment.yaml

# Test all templates
kubectl apply --dry-run=client -f .
```

## 🚀 Deployment Flow

1. **Secrets & ConfigMaps** - Credentials and configuration
2. **Persistent Volumes** - Storage preparation  
3. **Database** - MariaDB StatefulSet and Service
4. **WordPress** - Application Deployment and Service
5. **Ingress** - External access configuration (handled by deployment scripts)

## 📚 References

- **Kubernetes Documentation**: [kubernetes.io](https://kubernetes.io/docs/)
- **K3s Documentation**: [k3s.io](https://k3s.io/)
- **WordPress on Kubernetes**: [WordPress Official Guide](https://kubernetes.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/)

---
**Note**: These templates are designed for K3s environments but are compatible with standard Kubernetes clusters.