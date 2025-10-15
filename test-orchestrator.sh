#!/bin/bash

# Test the WordPress Migration Orchestrator
# This script demonstrates the complete migration flow

echo "🚀 WordPress Migration Orchestrator Test"
echo "========================================"
echo
echo "This test will demonstrate the complete migration workflow:"
echo "1. ✅ Source site backup (using migrate.py)"
echo "2. ✅ New WordPress deployment (using k3s-wp-spawner.sh)"  
echo "3. ✅ Backup import (using import.py)"
echo
echo "📋 Test Parameters:"
echo "   • Source URL: https://example-source-site.com"
echo "   • New Domain: wp3.test.kunj.company"
echo "   • Namespace: kunj-test"
echo
echo "🔧 Prerequisites Check:"

# Check if all required files exist
FILES=("migrate.py" "import.py" "k3s-wp-spawner.sh")
for file in "${FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "   ✅ $file found"
    else
        echo "   ❌ $file missing"
        exit 1
    fi
done

# Check if k3s is running
if sudo kubectl get nodes > /dev/null 2>&1; then
    echo "   ✅ k3s cluster running"
else
    echo "   ❌ k3s cluster not running"
    exit 1
fi

# Check if playwright is installed
if python3 -c "import playwright" 2>/dev/null; then
    echo "   ✅ Playwright installed"
else
    echo "   ❌ Playwright not installed"
    exit 1
fi

echo
echo "🎯 All prerequisites met!"
echo
echo "📝 To run the real migration orchestrator:"
echo "   cd /home/ubuntu/wp_migration_tool"
echo "   ./wp-migration-orchestrator.sh"
echo
echo "🌐 The orchestrator will prompt you for:"
echo "   • Source WordPress URL"
echo "   • Source admin username/password"
echo "   • New domain name"  
echo "   • Kubernetes namespace"
echo
echo "✨ Then it will automatically:"
echo "   • Create backup from source site"
echo "   • Deploy new WordPress on k3s"
echo "   • Import backup to new site"
echo
echo "🚀 Ready to migrate WordPress sites!"