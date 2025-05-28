#!/bin/bash

# Create the USB modeswitch configuration file
echo "# AC600 Wifi Dongle
TargetVendor=0x0bda
TargetProduct=0x1a2b
StandardEject=1" | sudo tee /usr/share/usb_modeswitch/0bda:1a2b > /dev/null

# Check if the file was created successfully
if [ -f "/usr/share/usb_modeswitch/0bda:1a2b" ]; then
    echo "USB modeswitch configuration file created successfully."
else
    echo "Failed to create USB modeswitch configuration file."
    exit 1
fi

# Modify the udev rules file
UDEV_RULES_FILE="/lib/udev/rules.d/40-usb_modeswitch.rules"
TEMP_FILE=$(mktemp)

# Check if the file exists
if [ ! -f "$UDEV_RULES_FILE" ]; then
    echo "Error: $UDEV_RULES_FILE not found."
    exit 1
fi

# Find the line with LABEL="modeswitch_rules_end" and insert our rule before it
awk '/LABEL="modeswitch_rules_end"/ {print "# Realtek 8811cu wifi usb"; print "ATTR{idVendor}==\"0bda\", ATTR{idProduct}==\"1a2b\", RUN+=\"usb_modeswitch \047/%k\047\""; print}1' "$UDEV_RULES_FILE" > "$TEMP_FILE"

# Replace the original file with our modified version
sudo cp "$TEMP_FILE" "$UDEV_RULES_FILE"
rm "$TEMP_FILE"

echo "Udev rules updated successfully."
echo "You may need to restart your system or reload udev rules for changes to take effect."
