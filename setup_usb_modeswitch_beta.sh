#!/bin/bash

# Get the absolute path for the log file
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
LOG_FILE="$SCRIPT_DIR/log_$(date +'%Y%m%d_%H%M%S').txt"

log_message() {
    local MESSAGE="$1"
    echo -e "$MESSAGE"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $MESSAGE" >> "$LOG_FILE"
}

# --- HARDWARE DETECTION PHASE ---
log_message "Starting Wifi Dongle Auto-Detection..."
echo "STEP 1: UNPLUG your Wifi Dongle (if it's plugged in)."

# Clear dmesg or take a snapshot of the current line count to ignore old logs
# We'll use a timestamp marker to only look at logs generated AFTER this point
MARKER_TIME=$(date +"%Y-%m-%d %H:%M:%S")

echo "STEP 2: PLUG IN your Wifi Dongle."
log_message "Waiting for kernel to detect the device..."

DETECTED_VENDOR=""
DETECTED_PRODUCT=""

# Loop until we find the IDs in dmesg
while [ -z "$DETECTED_VENDOR" ]; do
    sleep 2
    
    # We search dmesg for the most recent "New USB device found" entry
    # We extract idVendor and idProduct from the kernel output
    LAST_ENTRY=$(dmesg | tail -n 20)
    
    if echo "$LAST_ENTRY" | grep -q "idVendor="; then
        DETECTED_VENDOR=$(echo "$LAST_ENTRY" | grep -o "idVendor=[0-9a-fA-F]*" | tail -n 1 | cut -d'=' -f2)
        DETECTED_PRODUCT=$(echo "$LAST_ENTRY" | grep -o "idProduct=[0-9a-fA-F]*" | tail -n 1 | cut -d'=' -f2)
    fi
done

log_message "[FOUND] Kernel reported -> VendorID: $DETECTED_VENDOR, ProductID: $DETECTED_PRODUCT"
sleep 3

# --- STEP 1: Create usb_modeswitch configuration file ---
TARGET_CONFIG="/usr/share/usb_modeswitch/$DETECTED_VENDOR:$DETECTED_PRODUCT"

if [ -f "$TARGET_CONFIG" ]; then
    log_message "[SKIP] Configuration file '$TARGET_CONFIG' already exists."
else
    log_message "Step 1: Creating usb_modeswitch configuration file..."
    
    echo "# Auto-detected Wifi Dongle
TargetVendor=0x$DETECTED_VENDOR
TargetProduct=0x$DETECTED_PRODUCT
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
RULE_STRING="ATTR{idVendor}==\"$DETECTED_VENDOR\", ATTR{idProduct}==\"$DETECTED_PRODUCT\""

log_message "Step 2: Checking Udev rules in $UDEV_RULES_FILE..."

if [ ! -f "$UDEV_RULES_FILE" ]; then
    log_message "[ERROR] Udev rules file not found. Exiting."
    sleep 5
    exit 1
fi

if grep -q "$RULE_STRING" "$UDEV_RULES_FILE"; then
    log_message "[SKIP] Udev rules already contain this device."
else
    log_message "Applying new Udev rules for $DETECTED_VENDOR:$DETECTED_PRODUCT..."
    TEMP_FILE=$(mktemp)
    
    # Use awk to insert before the end label, passing IDs as variables
    awk -v vendor="$DETECTED_VENDOR" -v product="$DETECTED_PRODUCT" \
    '/LABEL="modeswitch_rules_end"/ {
        print "# Auto-detected wifi usb"; 
        print "ATTR{idVendor}==\""vendor"\", ATTR{idProduct}==\""product"\", RUN+=\"usb_modeswitch \047/%k\047\""; 
        print 
    }1' "$UDEV_RULES_FILE" > "$TEMP_FILE"

    if sudo cp "$TEMP_FILE" "$UDEV_RULES_FILE"; then
        rm "$TEMP_FILE"
        log_message "[SUCCESS] Udev rules updated successfully."
    else
        log_message "[ERROR] Failed to update Udev rules."
        rm "$TEMP_FILE"
        sleep 5
        exit 1
    fi
fi

sleep 3

# --- FINAL SUMMARY ---
echo "--------------------------------------------------"
log_message "PROCESS COMPLETED SUCCESSFULLY!"
log_message "Configured for Device: $DETECTED_VENDOR:$DETECTED_PRODUCT"
log_message "Log file saved at: $LOG_FILE"
echo "--------------------------------------------------"

# Wait 5 seconds before closing
sleep 5
