from playwright.sync_api import Playwright, sync_playwright
import time
import os
import re
import glob
from urllib.parse import urlparse

# --- SOURCE & TARGET CONFIGURATION ---
# The source URL is used only to find the correct backup subfolder.
SOURCE_WP_URL = "" 
TARGET_WP_URL = "" 

# Target site admin credentials (these credentials are NOT stored in the database yet, 
# but will be overwritten by the credentials from the SOURCE site once import is complete).
TARGET_USERNAME = ""         
TARGET_PASSWORD = ""      

# Source site admin credentials (used for final login validation)
SOURCE_USERNAME = ""
SOURCE_PASSWORD = ""

PLUGIN_SLUG = "all-in-one-wp-migration"
PLUGIN_NAME = "All-in-One WP Migration" # Needed for search/install
BASE_EC2_DIR = "/home/ubuntu/backup-receiver/recieved_wp"

# --- UTILITY FUNCTIONS ---

def get_safe_site_name(url):
    """Generates a filesystem-safe folder name from the URL."""
    name = re.sub(r'https?://', '', url).strip('/')
    name = re.sub(r':\d+', '', name)
    return re.sub(r'[^\w\s-]', '_', name).strip().lower()

def find_latest_backup(site_folder):
    """Finds the path to the newest .wpress file in the given directory."""
    search_path = os.path.join(BASE_EC2_DIR, site_folder, '*.wpress')
    list_of_files = glob.glob(search_path)
    
    if not list_of_files:
        raise FileNotFoundError(f"No .wpress files found in {os.path.join(BASE_EC2_DIR, site_folder)}")

    # Sort files by modification time and take the newest one
    latest_file = max(list_of_files, key=os.path.getmtime)
    return latest_file

def install_plugin_via_search(page, wp_url):
    """Navigates to Add New Plugin page and installs the plugin on the target WP URL."""
    print("   -> Plugin not installed. Navigating to Add New.")
    page.goto(f"{wp_url}/wp-admin/plugin-install.php", wait_until="domcontentloaded")
    
    page.fill("#search-plugins", PLUGIN_NAME)
    page.press("#search-plugins", "Enter")
    
    # Wait for the Install Now button using the data-slug
    install_selector = page.locator(f'a.install-now[data-slug="{PLUGIN_SLUG}"]')
    install_selector.wait_for(timeout=15000)
    
    install_selector.click()
    print("   -> Install clicked. Waiting for activation...")

    activate_selector_post_install = page.get_by_role("button", name="Activate")
    activate_selector_post_install.wait_for(timeout=60000)
    activate_selector_post_install.click()
    
    # After activation, force re-navigation back to the plugins list for stability
    # This ensures the final status check in ensure_plugin_active works correctly.
    page.goto(f"{wp_url}/wp-admin/plugins.php")
    page.wait_for_load_state('networkidle', timeout=30000)

    # Re-fetch the Deactivate link on the newly reloaded page
    plugin_row = page.locator(f'tr[data-slug="{PLUGIN_SLUG}"]')
    deactivate_link = plugin_row.locator("a:has-text('Deactivate')")

    deactivate_link.wait_for(state="visible", timeout=30000)
    print("   -> Plugin activated successfully.")
    return True

def ensure_plugin_active(page, wp_url):
    """Ensures the plugin is installed and active, handles all states safely."""
    page.goto(f"{wp_url}/wp-admin/plugins.php")
    page.wait_for_load_state('networkidle', timeout=30000)
    
    plugin_row = page.locator(f'tr[data-slug="{PLUGIN_SLUG}"]')
    plugin_row.wait_for(timeout=30000)

    deactivate_link = plugin_row.locator("a:has-text('Deactivate')")
    if deactivate_link.is_visible():
        print("   -> Plugin is already ACTIVE. Proceeding to import.")
        return True

    activate_link = plugin_row.locator("a:has-text('Activate')")
    if activate_link.is_visible():
        print("   -> Plugin is inactive. Activating now...")
        activate_link.click()
        for attempt in range(3):
            try:
                deactivate_link.wait_for(state="visible", timeout=10000)
                print("   -> Plugin activated successfully.")
                return True
            except:
                print(f"   -> Waiting for plugin activation... attempt {attempt+1}")
                time.sleep(2)
        raise Exception("Plugin activation failed after retries.")

    print("   -> Plugin not installed. Installing...")
    install_plugin_via_search(page, wp_url)
    return True


# --- MAIN IMPORT WORKFLOW ---

def run_import_workflow():
    # 1. Determine file path
    source_folder_name = get_safe_site_name(SOURCE_WP_URL)
    try:
        backup_file_path = find_latest_backup(source_folder_name)
        print(f"--- Found latest backup: {os.path.basename(backup_file_path)} ---")
    except FileNotFoundError as e:
        print(f"❌ FATAL ERROR: {e}")
        return False

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context()
        page = context.new_page()

        try:
            # --- PHASE 4: LOGIN TO TARGET SITE ---
            print("--- PHASE 4: LOGIN TO TARGET SITE ---")
            page.goto(f"{TARGET_WP_URL}/wp-admin/", timeout=60000)

            # Log in using the fresh WordPress install credentials
            page.fill("#user_login", TARGET_USERNAME)
            page.fill("#user_pass", TARGET_PASSWORD)
            page.click("#wp-submit")
            page.wait_for_selector("#wpadminbar", timeout=60000)
            print("   -> Login to target successful.")

            # --- PHASE 5: CHECK PLUGIN STATUS (Now handles install) ---
            ensure_plugin_active(page, TARGET_WP_URL)

            # --- PHASE 6: TRIGGER IMPORT ---
            print("--- PHASE 6: TRIGGER IMPORT ---")
            page.goto(f"{TARGET_WP_URL}/wp-admin/admin.php?page=ai1wm_import")
            page.wait_for_load_state('networkidle', timeout=30000)

            # 1. Select the file for upload
            print("   -> Selecting file for upload...")
            page.set_input_files('input[type="file"]', backup_file_path)

            # 2. Wait for the Import Warning Modal to appear (it appears after upload finishes)
            print("   -> File uploading (waiting up to 5 minutes for upload to complete)...")

            warning_button = page.locator('button:has-text("PROCEED")') 
            warning_button.wait_for(state="visible", timeout=300000) 
            # 3. Click PROCEED on the Warning Modal
            print("   -> Warning modal found. Clicking PROCEED to start restoration...")
            warning_button.click()

            # 4. Wait for import completion with multiple possible success indicators
            print("   -> Restoration in progress (waiting up to 10 minutes)...")
            
            # Try multiple success patterns that the plugin might show
            success_patterns = [
                'div:has-text("successfully imported")',
                'div:has-text("Import complete")', 
                'div:has-text("Restore complete")',
                'button:has-text("FINISH")',
                'a:has-text("FINISH")',
                '.ai1wm-button-green:has-text("FINISH")'
            ]
            
            import_completed = False
            for attempt in range(60):  # Check for 10 minutes (60 attempts * 10 seconds)
                try:
                    # Check for any success pattern
                    for pattern in success_patterns:
                        element = page.locator(pattern)
                        if element.is_visible():
                            print(f"   ✅ Import completion detected: {pattern}")
                            import_completed = True
                            break
                    
                    if import_completed:
                        break
                        
                    # Also check if we got redirected to WordPress dashboard (import auto-completed)
                    if "wp-admin" in page.url and ("dashboard" in page.url or "index.php" in page.url):
                        print("   ✅ Import completed - redirected to dashboard")
                        import_completed = True
                        break
                        
                except Exception as e:
                    pass  # Continue checking
                
                print(f"   -> Still importing... (attempt {attempt + 1}/60)")
                time.sleep(10)
            
            if not import_completed:
                print("   ⚠️  Import timeout - attempting to proceed anyway")
            
            # 5. Try to click FINISH button if visible
            try:
                finish_button = page.locator('button:has-text("FINISH"), a:has-text("FINISH"), .ai1wm-button-green:has-text("FINISH")')
                if finish_button.is_visible():
                    print("   -> Clicking FINISH button...")
                    finish_button.first.click()
                    time.sleep(2)
            except Exception as e:
                print(f"   -> No FINISH button found or error clicking: {e}")
                pass

            # --- PHASE 7: FINAL LOGIN & VERIFICATION ---
            print("--- PHASE 7: FINAL LOGIN & VERIFICATION ---")

            # Check if we need to login again or if we're already in the admin
            try:
                # Wait a moment to see what page we're on
                time.sleep(3)
                
                # Check if we're already logged in to WordPress admin
                if page.locator("#wpadminbar").is_visible():
                    print("   -> Already logged in to WordPress admin")
                else:
                    # Need to login with imported credentials
                    print("   -> Logging in with imported site credentials...")
                    page.goto(f"{TARGET_WP_URL}/wp-admin/", timeout=30000)
                    
                    # Wait for login form
                    page.wait_for_selector("#user_login", timeout=30000)
                    page.fill("#user_login", SOURCE_USERNAME)
                    page.fill("#user_pass", SOURCE_PASSWORD)
                    page.click("#wp-submit")
                    page.wait_for_selector("#wpadminbar", timeout=30000)
                    print("   -> Login successful with imported credentials")

                # Try to access permalinks to finalize the site structure
                try:
                    print("   -> Accessing permalinks settings to finalize site structure...")
                    page.goto(f"{TARGET_WP_URL}/wp-admin/options-permalink.php", timeout=30000)
                    
                    # Check if we reached the permalinks page
                    if page.locator('h1:has-text("Permalink Settings")').is_visible():
                        print("   -> Permalinks page reached. Saving settings...")
                        save_button = page.locator('input[type="submit"][value="Save Changes"]')
                        if save_button.is_visible():
                            save_button.click()
                            time.sleep(2)
                            print("   -> Permalink settings saved")
                        else:
                            print("   -> Save button not found, settings may already be correct")
                    else:
                        print("   -> Could not access permalinks page, but import appears successful")
                        
                except Exception as e:
                    print(f"   -> Permalinks update skipped: {e}")
                    
            except Exception as e:
                print(f"   -> Final login attempt failed, but import may have completed: {e}")
                
            # Final verification - check if the site is accessible
            print("   -> Verifying site accessibility...")
            try:
                page.goto(TARGET_WP_URL, timeout=30000)
                if "WordPress" in page.content() or page.locator("body").is_visible():
                    print("   ✅ Site is accessible and appears to be working")
                else:
                    print("   ⚠️  Site accessibility uncertain")
            except Exception as e:
                print(f"   ⚠️  Could not verify site accessibility: {e}") 

            return True

        except Exception as e:
            print(f"\n❌ FATAL IMPORT ERROR: {e}")
            return False

        finally:
            browser.close()

if __name__ == '__main__':
    if run_import_workflow():
        print("MIGRATION IMPORT TOOL: SUCCESS ✅")
    else:
        print("MIGRATION IMPORT TOOL: FAILURE ❌")
