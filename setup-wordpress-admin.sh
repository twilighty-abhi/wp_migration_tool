#!/bin/bash

# WordPress Admin Setup Script
# This script configures WordPress with admin credentials after deployment

NAMESPACE=""
DOMAIN=""
ADMIN_USER="admin"
ADMIN_PASS=""
ADMIN_EMAIL=""

usage() {
    echo "Usage: $0 -n NAMESPACE -d DOMAIN -p PASSWORD [-e EMAIL]"
    echo "  -n: Kubernetes namespace"
    echo "  -d: WordPress domain"
    echo "  -p: Admin password"
    echo "  -e: Admin email (optional, will prompt if not provided)"
    exit 1
}

while getopts "n:d:p:e:" opt; do
    case $opt in
        n) NAMESPACE="$OPTARG" ;;
        d) DOMAIN="$OPTARG" ;;
        p) ADMIN_PASS="$OPTARG" ;;
        e) ADMIN_EMAIL="$OPTARG" ;;
        *) usage ;;
    esac
done

if [[ -z "$NAMESPACE" || -z "$DOMAIN" || -z "$ADMIN_PASS" ]]; then
    usage
fi

# Prompt for admin email if not provided
if [[ -z "$ADMIN_EMAIL" ]]; then
    echo -n "Enter WordPress admin email: "
    read ADMIN_EMAIL
    
    # Validate email format (basic validation)
    if [[ ! "$ADMIN_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo "❌ Invalid email format. Using default: admin@example.com"
        ADMIN_EMAIL="admin@example.com"
    fi
fi

echo "🔧 Setting up WordPress admin for domain: $DOMAIN"

# Wait for WordPress to be ready
echo "⏳ Waiting for WordPress pod to be ready..."
sudo kubectl wait --for=condition=ready pod -l app=wordpress -n "$NAMESPACE" --timeout=300s

# Get WordPress pod name
POD_NAME=$(sudo kubectl get pods -n "$NAMESPACE" -l app=wordpress -o jsonpath='{.items[0].metadata.name}')

if [[ -z "$POD_NAME" ]]; then
    echo "❌ No WordPress pod found in namespace $NAMESPACE"
    exit 1
fi

echo "📋 Found WordPress pod: $POD_NAME"

# Install WP-CLI in the pod
echo "🔧 Installing WP-CLI..."
sudo kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bash -c "
    if ! command -v wp &> /dev/null; then
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x wp-cli.phar
        mv wp-cli.phar /usr/local/bin/wp
    fi
"

# Wait for WordPress to be accessible
echo "⏳ Waiting for WordPress to be accessible..."
for i in {1..30}; do
    if curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN" | grep -q "200\|30"; then
        break
    fi
    echo "   Attempt $i/30: Waiting for WordPress..."
    sleep 10
done

# Configure WordPress
echo "🔧 Configuring WordPress installation..."
sudo kubectl exec -n "$NAMESPACE" "$POD_NAME" -- wp core install \
    --url="http://$DOMAIN" \
    --title="WordPress Migration Site" \
    --admin_user="$ADMIN_USER" \
    --admin_password="$ADMIN_PASS" \
    --admin_email="$ADMIN_EMAIL" \
    --allow-root \
    --path="/var/www/html"

if [[ $? -eq 0 ]]; then
    echo "✅ WordPress admin setup completed successfully!"
    echo "🔑 Admin credentials:"
    echo "   Username: $ADMIN_USER"
    echo "   Password: $ADMIN_PASS"
    echo "   URL: http://$DOMAIN/wp-admin/"
else
    echo "❌ WordPress setup failed"
    exit 1
fi

# Install All-in-One WP Migration plugin
echo "🔌 Installing All-in-One WP Migration plugin..."
sudo kubectl exec -n "$NAMESPACE" "$POD_NAME" -- wp plugin install all-in-one-wp-migration --activate --allow-root --path="/var/www/html"

if [[ $? -eq 0 ]]; then
    echo "✅ All-in-One WP Migration plugin installed and activated!"
else
    echo "⚠️  Plugin installation failed, but WordPress setup is complete"
fi

echo "🎉 WordPress setup completed!"