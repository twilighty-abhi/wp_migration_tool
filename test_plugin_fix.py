#!/usr/bin/env python3

# Test script to verify the plugin detection fix
import sys
import os
import re

# Add current directory to Python path
sys.path.insert(0, '/home/ubuntu/wp_migration_tool')

# Import the migrate module
from migrate import ensure_plugin_active, install_plugin_via_search
from playwright.sync_api import sync_playwright

# Test configuration
WP_URL = "http://wp1.test.kunj.company"
USERNAME = "abhiram" 
PASSWORD = "password123"

def test_plugin_detection():
    """Test the plugin detection without full workflow."""
    print("🧪 Testing Plugin Detection Fix...")
    
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context()
        page = context.new_page()
        
        try:
            # Login
            print("→ Logging into WordPress...")
            page.goto(f"{WP_URL}/wp-admin/")
            page.fill("#user_login", USERNAME)
            page.fill("#user_pass", PASSWORD)
            page.click("#wp-submit")
            page.wait_for_selector("#wpadminbar", timeout=30000)
            print("✅ Login successful")
            
            # Test plugin detection
            print("→ Testing plugin detection...")
            page.goto(f"{WP_URL}/wp-admin/plugins.php")
            page.wait_for_load_state('networkidle', timeout=15000)
            
            # Test our fixed function
            result = ensure_plugin_active(page)
            if result:
                print("✅ Plugin detection test PASSED")
                return True
            else:
                print("❌ Plugin detection test FAILED")
                return False
                
        except Exception as e:
            print(f"❌ Test failed with error: {e}")
            return False
        finally:
            browser.close()

if __name__ == '__main__':
    success = test_plugin_detection()
    sys.exit(0 if success else 1)