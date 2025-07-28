#!/bin/bash

# ==============================================================================
# Framework Laptop Tweak Script for Fedora
#
# This script interactively applies common fixes for Framework Laptops running
# standard Fedora. It detects your hardware and prompts for each change.
#
# Usage:
# 1. Save this file as 'framework-tweaks.sh'
# 2. Make it executable: chmod +x framework-tweaks.sh
# 3. Run it: ./framework-tweaks.sh
# ==============================================================================

# --- Configuration and Colors ---
# Use color codes for better readability
C_BLUE="\e[34m"
C_GREEN="\e[32m"
C_YELLOW="\e[33m"
C_RED="\e[31m"
C_RESET="\e[0m"

# --- Global Variables ---
REBOOT_NEEDED=false

# --- Functions ---

# Function to display a header for each section
print_header() {
    echo -e "\n${C_BLUE}# --- $1 --- #${C_RESET}"
}

# Function to prompt the user for an action (Apply, Reverse, Skip)
prompt_user() {
    local description="$1"
    local apply_cmd="$2"
    local reverse_cmd="$3"
    local requires_reboot="${4:-false}"

    echo -e "${C_YELLOW}Description:${C_RESET} $description"
    while true; do
        read -p "Choose an action: [A]pply, [R]everse, or [S]kip? " -n 1 -r choice
        echo # Move to a new line
        case "$choice" in
            [aA])
                echo -e "${C_GREEN}Applying fix...${C_RESET}"
                eval "$apply_cmd"
                if [ "$requires_reboot" = true ]; then
                    REBOOT_NEEDED=true
                fi
                break
                ;;
            [rR])
                echo -e "${C_RED}Reversing fix...${C_RESET}"
                eval "$reverse_cmd"
                if [ "$requires_reboot" = true ]; then
                    REBOOT_NEEDED=true
                fi
                break
                ;;
            [sS])
                echo "Skipping."
                break
                ;;
            *)
                echo -e "${C_RED}Invalid input. Please enter A, R, or S.${C_RESET}"
                ;;
        esac
    done
}

# --- Script Start ---

# 1. Request Administrator Privileges
echo "This script needs administrator privileges to modify system files."
sudo -v
# Keep sudo session alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo -e "${C_GREEN}Welcome to the Framework Laptop Fedora Tweak Script!${C_RESET}"
echo "Let's check your hardware and see what we can optimize."

# 2. Hardware Detection
print_header "HARDWARE DETECTION"
CPU_VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $NF}')
CHASSIS_VENDOR=$(sudo cat /sys/class/dmi/id/chassis_vendor)
PRODUCT_NAME=$(sudo cat /sys/class/dmi/id/product_name)
BIOS_VERSION=$(sudo cat /sys/class/dmi/id/bios_version 2>/dev/null)

echo "  - CPU Vendor:     $CPU_VENDOR"
echo "  - Chassis Vendor: $CHASSIS_VENDOR"
echo "  - Product Name:   $PRODUCT_NAME"
echo "  - BIOS Version:   $BIOS_VERSION"

# 3. Apply/Reverse Fixes
print_header "KERNEL ARGUMENT FIXES"

# --- Fix 1: Remove 'nomodeset' ---
prompt_user \
    "Removes the 'nomodeset' kernel argument. This is crucial for enabling proper graphics card drivers and performance. It should almost always be removed." \
    "sudo grubby --update-kernel=ALL --remove-args=\"nomodeset\" && echo 'Removed nomodeset.'" \
    "sudo grubby --update-kernel=ALL --args=\"nomodeset\" && echo 'Added nomodeset.'" \
    true

# --- Fix 2: Intel-specific Keyboard Backlight Fix ---
if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    prompt_user \
        "Blacklists the 'hid_sensor_hub' module on Intel-based Frameworks. This can prevent issues with the keyboard backlight and ambient light sensor." \
        "sudo grubby --update-kernel=ALL --args=\"module_blacklist=hid_sensor_hub\" && echo 'Blacklisted hid_sensor_hub.'" \
        "sudo grubby --update-kernel=ALL --remove-args=\"module_blacklist=hid_sensor_hub\" && echo 'Removed hid_sensor_hub blacklist.'" \
        true
else
    echo -e "\n${C_GREEN}Skipping Intel-specific fix (you have an AMD CPU).${C_RESET}"
fi


# --- AMD-specific Fixes ---
if [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
    print_header "AMD-SPECIFIC FIXES"

    # --- Fix 3: AMD Suspend Workaround ---
    SUSPEND_FIX_FILE="/etc/udev/rules.d/99-framework-suspend.rules"
    SUSPEND_FIX_CONTENT='ACTION==\"add\", SUBSYSTEM==\"serio\", DRIVERS==\"atkbd\", ATTR{power/wakeup}=\"disabled\"'
    prompt_user \
        "Applies a suspend workaround for AMD models. This prevents the keyboard from waking the system immediately after sleep, which can be an issue on some BIOS versions." \
        "echo '$SUSPEND_FIX_CONTENT' | sudo tee '$SUSPEND_FIX_FILE' > /dev/null && echo 'Suspend fix applied.'" \
        "sudo rm -f '$SUSPEND_FIX_FILE' && echo 'Suspend fix file removed.'" \
        true
else
    echo -e "\n${C_GREEN}Skipping AMD-specific fixes (you have an Intel CPU).${C_RESET}"
fi


# 4. Final Reboot Prompt
print_header "ALL DONE"
if [ "$REBOOT_NEEDED" = true ]; then
    echo -e "${C_YELLOW}Changes have been made that require a system reboot to take effect.${C_RESET}"
    while true; do
        read -p "Would you like to reboot now? [y/n] " -n 1 -r choice
        echo
        case "$choice" in
            [yY])
                echo "Rebooting now..."
                sudo reboot
                break
                ;;
            [nN])
                echo "Please remember to reboot your computer later."
                break
                ;;
            *)
                echo -e "${C_RED}Invalid input. Please enter y or n.${C_RESET}"
                ;;
        esac
    done
else
    echo "No changes requiring a reboot were made."
fi

echo -e "${C_GREEN}Exiting script. Have a great day!${C_RESET}"
