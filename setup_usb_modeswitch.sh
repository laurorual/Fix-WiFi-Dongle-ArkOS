#!/bin/bash

# 1. Log Configuration
# Generates a unique log file name based on current date and time
LOG_FILE="log_$(date +'%Y%m%d_%H%M%S').txt"

# Function to log messages to both the terminal and the text file
log_message() {
    local MESSAGE="$1"
    echo -e "$MESSAGE"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $MESSAGE" >> "$LOG_FILE"
}

# Start of the script
log_message "Starting Wifi Dongle configuration..."
sleep 3

# --- STEP 1: Create usb_modeswitch configuration file ---
TARGET_CONFIG="/usr/share/usb_modeswitch/0bda:1a2b"

if [ -f "$TARGET_CONFIG" ]; then
    log_message "[SKIP] Configuration file '$TARGET_CONFIG' already exists. No changes made."
else
    log_message "Step 1: Creating usb_modeswitch configuration file..."
    
    echo "# AC600 Wifi Dongle
TargetVendor=0x0bda
TargetProduct=0x1a2b
StandardEject=1" | sudo tee "$TARGET_CONFIG" > /dev/null

    if [ -f "$TARGET_CONFIG" ]; then
        log_message "[SUCCESS] usb_modeswitch configuration file created."
    else
        log_message "[ERROR] Failed to create configuration file. Exiting."
        sleep 5
        exit 1
    fi
fi

sleep 3

# --- STEP 2: Modify Udev rules ---
UDEV_RULES_FILE="/lib/udev/rules.d/40-usb_modeswitch.rules"
RULE_STRING="ATTR{idVendor}==\"0bda\", ATTR{idProduct}==\"1a2b\""

log_message "Step 2: Checking Udev rules in $UDEV_RULES_FILE..."

if [ ! -f "$UDEV_RULES_FILE" ]; then
    log_message "[ERROR] Udev rules file not found at $UDEV_RULES_FILE. Exiting."
    sleep 5
    exit 1
fi

# Check if the specific rule already exists in the file
if grep -q "$RULE_STRING" "$UDEV_RULES_FILE"; then
    log_message "[SKIP] Udev rules already contain the configuration for this device."
else
    log_message "Applying new Udev rules..."
    TEMP_FILE=$(mktemp)
    
    # Insert the rule before the end label
    awk '/LABEL="modeswitch_rules_end"/ {print "# Realtek 8811cu wifi usb"; print "ATTR{idVendor}==\"0bda\", ATTR{idProduct}==\"1a2b\", RUN+=\"usb_modeswitch \047/%k\047\""; print}1' "$UDEV_RULES_FILE" > "$TEMP_FILE"

    if sudo cp "$TEMP_FILE" "$UDEV_RULES_FILE"; then
        rm "$TEMP_FILE"
        log_message "[SUCCESS] Udev rules updated successfully."
    else
        log_message "[ERROR] Failed to update Udev rules. Permission issue?"
        rm "$TEMP_FILE"
        sleep 5
        exit 1
    fi
fi

sleep 3

# --- FINAL SUMMARY ---
echo "--------------------------------------------------"
log_message "PROCESS COMPLETED!"
log_message "Log file saved as: $(pwd)/$LOG_FILE"
log_message "You may need to restart your device for changes to take effect."
echo "--------------------------------------------------"

# Wait 5 seconds before closing
sleep 5
