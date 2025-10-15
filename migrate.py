from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError
import time
import os
import re
import requests

# --- CONFIGURATION ---
WP_URL = "http://wp1.test.kunj.company"  # Ensure protocol included
# USERNAME = "Tech4Good"
# PASSWORD = "Tech4Good@"
USERNAME = "abhiram"
PASSWORD = "abhiram"
PLUGIN_SLUG = "all-in-one-wp-migration"
PLUGIN_NAME = "All-In-One WP Migration"

# --- BASE SAVE DIR ON EC2 INSTANCE ---
BASE_EC2_DIR = "/home/ubuntu/backup-receiver/recieved_wp"

# --- UTILITY FUNCTIONS ---

def get_safe_site_name(url):
    """Generates a filesystem-safe folder name from the URL."""
    name = re.sub(r'https?://', '', url).strip('/')
    name = re.sub(r':\d+', '', name)
    return re.sub(r'[^\w\s-]', '_', name).strip().lower()

def perform_with_retries(action, description="", retries=5, delay=2):
    for attempt in range(1, retries + 1):
        try:
            print(f"Attempt {attempt}/{retries} - {description}")
            action()
            print(f"{description} succeeded.")
            return True
        except PlaywrightTimeoutError as e:
            print(f"{description} timeout on attempt {attempt}: {e}")
        except Exception as e:
            print(f"{description} failed on attempt {attempt}: {e}")
        time.sleep(delay * (2 ** (attempt - 1)))  # exponential backoff on retries
    print(f"All retries exhausted for: {description}")
    return False

def install_plugin_via_search(page):
    print("   -> Plugin not found, navigating to Add New Plugins...")
    page.goto(f"{WP_URL}/wp-admin/plugin-install.php", wait_until="domcontentloaded")

    def search_and_click_install():
        page.fill("#search-plugins", PLUGIN_NAME)
        page.press("#search-plugins", "Enter")
        page.wait_for_selector(f'a.install-now[data-slug="{PLUGIN_SLUG}"]', timeout=20000)
        install_btn = page.locator(f'a.install-now[data-slug="{PLUGIN_SLUG}"]')
        install_btn.click()
        page.wait_for_load_state('networkidle', timeout=60000)  # Wait for install completion

    if not perform_with_retries(search_and_click_install, "Plugin search and click install"):
        raise Exception("Failed to click plugin install")

    def click_activate():
        activate_btn = page.locator(f'a.activate-now[data-slug="{PLUGIN_SLUG}"]')
        activate_btn.click()
        page.wait_for_load_state('networkidle', timeout=60000)  # Wait for activation

    if not perform_with_retries(click_activate, "Activate plugin"):
        raise Exception("Plugin activation failed")

def ensure_plugin_active(page):
    plugin_row = page.locator(f'tr[data-slug="{PLUGIN_SLUG}"]')

    try:
        plugin_row.wait_for(timeout=7000)
    except PlaywrightTimeoutError:
        print("   -> Plugin not installed. Installing now...")
        install_plugin_via_search(page)
        return True

    deactivate_link = plugin_row.locator("a:has-text('Deactivate')")
    if deactivate_link.is_visible():
        print("   -> Plugin already active.")
        return True

    activate_link = plugin_row.locator("a:has-text('Activate')")
    if activate_link.is_visible():
        print("   -> Plugin inactive, activating...")
        if perform_with_retries(activate_link.click, "Activate plugin"):
            page.wait_for_load_state('networkidle')
            return True
        else:
            print("Activation failed, reinstalling plugin.")
            install_plugin_via_search(page)
            return True

    print("Plugin state unclear, reinstalling plugin.")
    install_plugin_via_search(page)
    return True

def login_with_retry(page, wp_url, admin_user, admin_pass, max_retries=3):
    for attempt in range(max_retries):
        try:
            print(f"Login attempt {attempt + 1}/{max_retries}...")
            page.goto(f"{wp_url}/wp-login.php", timeout=30000)
            page.fill("#user_login", admin_user)
            page.fill("#user_pass", admin_pass)
            page.click("#wp-submit")
            page.wait_for_selector("#wpadminbar", timeout=45000)
            print("Login successful.")
            return True
        except Exception as e:
            print(f"Login failed on attempt {attempt + 1}: {e}")
            try:
                page.context.clear_cookies()
            except Exception:
                pass
            time.sleep(3 * attempt)
    print("All login attempts failed.")
    return False

def click_element_with_retries(locator, max_retries=3, delay=3):
    for attempt in range(max_retries):
        try:
            if locator.is_visible() and locator.is_enabled():
                locator.click()
                return True
        except Exception as e:
            print(f"Click attempt {attempt + 1} failed: {e}")
        time.sleep(delay)
    return False

def download_file_directly(url, save_path):
    print(f"Downloading backup directly from URL: {url}")
    try:
        with requests.get(url, stream=True) as r:
            r.raise_for_status()
            with open(save_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    if chunk:  # filter out keep-alive chunks
                        f.write(chunk)
        print(f"Backup downloaded successfully to: {save_path}")
        return True
    except Exception as e:
        print(f"Failed to download the backup file directly: {e}")
        return False

def run_migration_workflow(wp_url, admin_user, admin_pass):
    wp_site_folder = get_safe_site_name(wp_url)
    site_save_dir = os.path.join(BASE_EC2_DIR, wp_site_folder)
    os.makedirs(site_save_dir, exist_ok=True)
    print(f"Save directory: {site_save_dir}")

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=["--no-sandbox"])  # add no-sandbox if on cloud/EC2
        context = browser.new_context(accept_downloads=True)
        context.set_default_timeout(60000)  # Default 60s timeout for waits
        page = context.new_page()

        # Clear cookies/permissions before login for fresh start
        page.context.clear_cookies()
        page.context.clear_permissions()

        if not login_with_retry(page, wp_url, admin_user, admin_pass):
            print("Login failed, aborting workflow.")
            return False

        try:
            print("Checking plugin status...")
            page.goto(f"{wp_url}/wp-admin/plugins.php")
            page.wait_for_load_state('networkidle', timeout=30000)

            if not perform_with_retries(lambda: ensure_plugin_active(page), "Ensure plugin active"):
                raise Exception("Plugin activation failed")

            print("Triggering export page...")
            page.goto(f"{wp_url}/wp-admin/admin.php?page=ai1wm_export")
            export_btn = page.locator('div.ai1wm-button-main')
            export_btn.wait_for(state="visible", timeout=120000)

            if not click_element_with_retries(export_btn, max_retries=5, delay=5):
                raise Exception("Failed to click Export Site button")

            print("Clicking 'File' export option...")
            file_btn = page.locator("#ai1wm-export-file")
            if not click_element_with_retries(file_btn, max_retries=5, delay=5):
                raise Exception("Failed to click File export button")

            print("Waiting for download link to appear...")
            dl_link = page.locator('a.ai1wm-button-download')
            dl_link.wait_for(state="visible", timeout=600000)

            # Extract the download URL and download file directly with requests
            download_url = dl_link.get_attribute("href")
            if not download_url:
                raise Exception("Failed to retrieve download URL from export page.")

            final_path = os.path.join(site_save_dir, os.path.basename(download_url))

            if not download_file_directly(download_url, final_path):
                raise Exception("Direct download of backup failed.")

            # Safely click CLOSE button if present
            try:
                close_btn = page.get_by_role("button", name="CLOSE")
                if close_btn.is_visible():
                    close_btn.click()
            except Exception as e:
                print(f"Close button not found or clickable: {e}")

            print("Workflow complete.")
            return True

        except Exception as e:
            print(f"Workflow error: {e}")
            try:
                page.screenshot(path="error_screenshot.png")
                print("Screenshot saved as error_screenshot.png")
            except Exception:
                pass
            return False

        finally:
            browser.close()

if __name__ == '__main__':
    if run_migration_workflow(WP_URL, USERNAME, PASSWORD):
        print("MIGRATION TOOL: SUCCESS. Check backup files.")
    else:
        print("MIGRATION TOOL: FAILURE. Check logs for errors.")
