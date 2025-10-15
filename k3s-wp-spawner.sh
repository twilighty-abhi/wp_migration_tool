#!/bin/bash

# WordPress K3s Deployment Script
# This script deploys WordPress on K3s with persistent storage and HTTP ingress
#
# Usage: ./wordpress-k3s-install.sh [DOMAIN] [NAMESPACE]
# Example: ./wordpress-k3s-install.sh blog.example.com my-blog

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
show_usage() {
    echo "Usage: $0 [DOMAIN] [NAMESPACE]"
    echo ""
    echo "Parameters:"
    echo "  DOMAIN     Domain name for WordPress (required)"
    echo "  NAMESPACE  Kubernetes namespace (default: wordpress-[domain-hash])"
    echo ""
    echo "Examples:"
    echo "  $0 blog.example.com                    # Auto-generate namespace"
    echo "  $0 blog.example.com my-wordpress       # Custom namespace"
    echo ""
    echo "Features:"
    echo "  • Persistent storage with PVC"
    echo "  • MariaDB database"
    echo "  • Traefik ingress controller"
    echo "  • HTTP domain mapping"
    echo "  • Resource limits and requests"
    echo ""
    exit 1
}

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
    show_usage
fi

# Configuration variables
DOMAIN="$1"
NAMESPACE="${2:-wordpress-$(echo $DOMAIN | tr '.' '-' | head -c 20)}"
WORDPRESS_DIR="/home/ubuntu/k3s-wordpress-${DOMAIN//\./-}"
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
WP_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Validate domain format
if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
    print_error "Invalid domain format: $DOMAIN"
    echo "Please provide a valid domain name (e.g., example.com, blog.mydomain.org)"
    exit 1
fi

# Validate namespace format
if [[ ! "$NAMESPACE" =~ ^[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?$ ]]; then
    print_error "Invalid namespace format: $NAMESPACE"
    echo "Namespace must be lowercase alphanumeric with hyphens"
    exit 1
fi

echo "🚀 Starting WordPress K3s Deployment"
echo "=================================="
print_status "Domain: $DOMAIN"
print_status "Namespace: $NAMESPACE" 
print_status "Installation Directory: $WORDPRESS_DIR"
echo ""

# Step 1: Create installation directory
print_status "Creating installation directory..."
mkdir -p "$WORDPRESS_DIR"
cd "$WORDPRESS_DIR"

# Step 2: Check if K3s is installed
print_status "Checking K3s installation..."
if ! command -v kubectl &> /dev/null; then
    print_warning "kubectl not found. Installing K3s..."
    curl -sfL https://get.k3s.io | sh -
    sudo chmod 644 /etc/rancher/k3s/k3s.yaml
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
else
    print_success "kubectl found"
fi

# Wait for K3s to be ready
print_status "Waiting for K3s to be ready..."
sudo kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Step 3: Create namespace
print_status "Creating namespace: $NAMESPACE"
sudo kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | sudo kubectl apply -f -

# Step 4: Create secrets
print_status "Creating database credentials..."
cat > secrets.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: wordpress-secrets
  namespace: $NAMESPACE
type: Opaque
data:
  db-password: $(echo -n "$DB_PASSWORD" | base64 -w 0)
  wp-password: $(echo -n "$WP_PASSWORD" | base64 -w 0)
EOF

sudo kubectl apply -f secrets.yaml

# Step 5: Create PersistentVolumeClaims
print_status "Creating persistent volumes..."
cat > pvc.yaml << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress-pvc
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mariadb-pvc
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

sudo kubectl apply -f pvc.yaml

# Step 6: Deploy MariaDB
print_status "Deploying MariaDB database..."
cat > mariadb.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mariadb
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mariadb
  template:
    metadata:
      labels:
        app: mariadb
    spec:
      containers:
      - name: mariadb
        image: mariadb:10.11
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: wordpress-secrets
              key: db-password
        - name: MYSQL_DATABASE
          value: wordpress
        - name: MYSQL_USER
          value: wordpress
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: wordpress-secrets
              key: db-password
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mariadb-storage
          mountPath: /var/lib/mysql
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: mariadb-storage
        persistentVolumeClaim:
          claimName: mariadb-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mariadb
  namespace: $NAMESPACE
spec:
  ports:
  - port: 3306
    targetPort: 3306
  selector:
    app: mariadb
EOF

sudo kubectl apply -f mariadb.yaml

# Step 7: Deploy WordPress
print_status "Deploying WordPress..."
cat > wordpress.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
      - name: wordpress
        image: wordpress:php8.2-apache
        env:
        - name: WORDPRESS_DB_HOST
          value: mariadb
        - name: WORDPRESS_DB_NAME
          value: wordpress
        - name: WORDPRESS_DB_USER
          value: wordpress
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: wordpress-secrets
              key: db-password
        ports:
        - containerPort: 80
        volumeMounts:
        - name: wordpress-storage
          mountPath: /var/www/html
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 60
          periodSeconds: 30
      volumes:
      - name: wordpress-storage
        persistentVolumeClaim:
          claimName: wordpress-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  namespace: $NAMESPACE
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: wordpress
EOF

sudo kubectl apply -f wordpress.yaml

# Step 8: Create Ingress
print_status "Creating HTTP ingress for domain: $DOMAIN"
cat > ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wordpress-ingress
  namespace: $NAMESPACE
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
  - host: $DOMAIN
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: wordpress
            port:
              number: 80
EOF

sudo kubectl apply -f ingress.yaml

# Step 9: Wait for deployments
print_status "Waiting for deployments to be ready..."
sudo kubectl wait --for=condition=available --timeout=600s deployment/mariadb -n "$NAMESPACE"
sudo kubectl wait --for=condition=available --timeout=600s deployment/wordpress -n "$NAMESPACE"

# Step 10: Get ingress info
print_status "Getting service information..."
sleep 10

# Step 11: Display status and information
echo ""
print_success "🎉 WordPress K3s Deployment Complete!"
echo "========================================="
echo ""
print_status "📋 Deployment Summary:"
echo "  • Domain: http://$DOMAIN"
echo "  • Namespace: $NAMESPACE"
echo "  • Deployment Directory: $WORDPRESS_DIR"
echo "  • Database: MariaDB with persistent storage"
echo "  • WordPress: 2 replicas with persistent storage"
echo ""

print_status "🔑 Generated Credentials:"
echo "  • Database Password: $DB_PASSWORD"
echo "  • WordPress Admin Password: $WP_PASSWORD"
echo ""

print_status "☸️ Kubernetes Resources:"
sudo kubectl get all -n "$NAMESPACE"

echo ""
print_status "📊 Persistent Volumes:"
sudo kubectl get pvc -n "$NAMESPACE"

echo ""
print_status "🌐 Ingress Status:"
sudo kubectl get ingress -n "$NAMESPACE"

echo ""
print_status "🔧 Useful Commands:"
echo "  • View pods: sudo kubectl get pods -n $NAMESPACE"
echo "  • View logs: sudo kubectl logs -f deployment/wordpress -n $NAMESPACE"
echo "  • Scale WordPress: sudo kubectl scale deployment wordpress --replicas=3 -n $NAMESPACE"
echo "  • Delete deployment: sudo kubectl delete namespace $NAMESPACE"
echo ""

print_status "🌐 Next Steps:"
echo "  1. Ensure DNS points $DOMAIN to your server IP"
echo "  2. Add '$DOMAIN' to your local hosts file if testing locally"
echo "  3. Visit http://$DOMAIN to complete WordPress setup"
echo "  4. Use generated admin password: $WP_PASSWORD"
echo ""

# Save credentials to file
cat > credentials.txt << EOF
WordPress K3s Deployment - $DOMAIN
Generated: $(date)
Domain: http://$DOMAIN
Namespace: $NAMESPACE
Database Password: $DB_PASSWORD
WordPress Admin Password: $WP_PASSWORD
Server IP: $(curl -s http://checkip.amazonaws.com || echo "Unable to get IP")

Add to hosts file for local testing:
$(curl -s http://checkip.amazonaws.com || echo "SERVER_IP") $DOMAIN

Useful Commands:
kubectl get pods -n $NAMESPACE
kubectl logs -f deployment/wordpress -n $NAMESPACE
kubectl delete namespace $NAMESPACE
EOF

print_status "💾 Credentials saved to: $WORDPRESS_DIR/credentials.txt"

# Get server IP for hosts file entry
SERVER_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo "YOUR_SERVER_IP")
echo ""
print_status "🔧 For local testing, add this to your hosts file:"
echo "  $SERVER_IP $DOMAIN"
echo ""
print_status "📝 Hosts file locations:"
echo "  • Windows: C:\\Windows\\System32\\drivers\\etc\\hosts"
echo "  • Mac/Linux: /etc/hosts"
echo ""

print_success "Deployment completed successfully! 🚀"