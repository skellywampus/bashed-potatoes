#!/bin/bash

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script as root or with sudo."
  exit 1
fi

sudo apt install dialog -y

# Prompt for root password
ROOT_PASS=$(dialog --stdout --insecure --passwordbox "Enter the desired root password:" 10 60)
if [ -z "$ROOT_PASS" ]; then
  echo "No root password entered, aborting."
  exit 1
fi
echo "root:$ROOT_PASS" | chpasswd

# Set up automatic login as root on tty1
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat << 'EOF' > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
Type=simple
EOF
systemctl daemon-reload

# Paths
HELP_FILE="/usr/local/etc/help_instructions.txt"
CUSTOM_ENTRIES_FILE="/usr/local/etc/custom_menu_entries.txt"

# Create or overwrite help instructions
mkdir -p /usr/local/etc
cat << 'HELP' > "$HELP_FILE"
Welcome to Bashed Potatoes!

Navigation:
- Use arrow keys to move between menu items.
- Press Enter to select an option.
- Press ESC or Cancel to return to the previous menu.

Main Menu Options:
- command: Run shell commands directly
- file: Open File Manager (mc)
- browse: Browse the Web (links2)
- apt: Manage packages without typing commands
- customize: Add or remove custom menu items
- system: Manage system tasks (shutdown, reboot, Wi-Fi, monitoring, timeshift, etc.)

Use CTRL+C to close programs and return to the main menu.

Open/edit files and launch videos/images through mc directly.

For command examples and quick help, use the 'Command Help (tldr)' option.
HELP

touch "$CUSTOM_ENTRIES_FILE"

echo "Updating and upgrading the system..."
apt update && apt upgrade -y

# Install necessary packages
# Added dosfstools, exfatprogs, ntfs-3g for formatting; fbset and console-setup for display resolution and setfont scaling
PACKAGES="network-manager links2 mc fim imagemagick btop util-linux fzf tldr mpv ncdu adduser timeshift dosfstools exfatprogs ntfs-3g fbset console-setup"
echo "Installing required dependencies..."
apt install -y $PACKAGES || { echo "Failed to install required packages: $PACKAGES"; exit 1; }

# Check commands are installed
for cmd in dialog fzf fim mpv btop nano mc nmtui links2 tldr ncdu adduser timeshift fbset setfont; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Command '$cmd' not found after installation."
    exit 1
  fi
done

echo "Enabling Network Manager..."
systemctl enable NetworkManager
systemctl start NetworkManager

# Create the main menu script
cat << 'EOF' > /usr/local/bin/menu
#!/bin/bash

CUSTOM_ENTRIES_FILE="/usr/local/etc/custom_menu_entries.txt"
HELP_FILE="/usr/local/etc/help_instructions.txt"
TMP_DIR="/tmp/menu_temp"
mkdir -p "$TMP_DIR"

main_menu() {
  while true; do
    MENU_ENTRIES=(
      command "Run shell commands directly"
      file "Open File Manager (mc)"
      browse "Browse the Web (links2)"
      apt "Manage Packages (APT)"
      customize "Customize Menu Entries"
      system "System Tasks"
      exit "Exit to Terminal"
    )

    # Append custom entries from the file
    if [ -s "$CUSTOM_ENTRIES_FILE" ]; then
      while IFS='|' read -r NAME DESC CMD; do
        [ -n "$NAME" ] && MENU_ENTRIES+=("$NAME" "$DESC")
      done < "$CUSTOM_ENTRIES_FILE"
    fi

    CHOICE=$(dialog --clear --backtitle "Bashed Potatoes" --title "Main Menu" --menu "Select an option:" 20 70 12 "${MENU_ENTRIES[@]}" 3>&1 1>&2 2>&3)
    
    case "$CHOICE" in
      "command")
        CMD=$(dialog --stdout --inputbox "Enter command to run:" 10 60)
	if [ -n "$CMD" ]; then
 	  clear
  	  $CMD 2>&1
  	  echo
   	  echo "Press any key to continue..."
    	  read -n1
     	else
      	  dialog --msgbox "No/Invalid command entered." 10 60
	fi
        ;;
      "file")
        mc
        ;;
      "browse")
        URL=$(dialog --stdout --inputbox "Enter the URL to browse:" 10 60 "http://")
        [ -n "$URL" ] && links2 -g "$URL"
        ;;
      "apt")
        apt_menu
        ;;
      "customize")
        customize_menu
        ;;
      "system")
        system_menu
        ;;
      "exit")
        clear
        exit 0
        ;;
      *)
        # Check if it matches a custom entry
        if grep -q "^$CHOICE|" "$CUSTOM_ENTRIES_FILE"; then
          CMD=$(grep "^$CHOICE|" "$CUSTOM_ENTRIES_FILE" | cut -d'|' -f3-)
          eval "$CMD"
        fi
        ;;
    esac
  done
}

apt_menu() {
  while true; do
    APT_CHOICE=$(dialog --clear --backtitle "APT Manager" --title "APT Menu" --menu "Select an action:" 15 60 5 \
      "update" "Update & Upgrade the system" \
      "install" "Install a Package" \
      "remove" "Remove a Package" \
      "back" "Return to Main Menu" 3>&1 1>&2 2>&3)
    case "$APT_CHOICE" in
      "update")
        apt update && apt upgrade -y
        dialog --msgbox "System updated." 10 60
        ;;
      "install")
        PKG=$(dialog --stdout --inputbox "Enter package name to install:" 10 60)
        [ -n "$PKG" ] && apt install -y "$PKG" && dialog --msgbox "Package '$PKG' installed successfully." 10 60
        ;;
      "remove")
        PKG=$(dialog --stdout --inputbox "Enter package name to remove:" 10 60)
        [ -n "$PKG" ] && apt remove -y "$PKG" && dialog --msgbox "Package '$PKG' removed successfully." 10 60
        ;;
      "back"|"")
        break
        ;;
    esac
  done
}

customize_menu() {
  while true; do
    CUSTOM_CHOICE=$(dialog --clear --backtitle "Customize Menu" --title "Customize Menu Entries" --menu "Select an action:" 15 60 5 \
      "add" "Add a custom menu entry" \
      "remove" "Remove a custom menu entry" \
      "back" "Return to Main Menu" 3>&1 1>&2 2>&3)

    case "$CUSTOM_CHOICE" in
      "add")
        NEW_NAME=$(dialog --stdout --inputbox "Enter a name for the menu entry:" 10 60)
        [ -n "$NEW_NAME" ] && NEW_DESC=$(dialog --stdout --inputbox "Enter a description:" 10 60) && \
          NEW_CMD=$(dialog --stdout --inputbox "Enter the command to run:" 10 60) && \
          echo "$NEW_NAME|$NEW_DESC|$NEW_CMD" >> "$CUSTOM_ENTRIES_FILE"
        ;;
      "remove")
        ENTRIES=()
        while IFS='|' read -r NAME DESC CMD; do
          [ -n "$NAME" ] && ENTRIES+=("$NAME" "$DESC")
        done < "$CUSTOM_ENTRIES_FILE"
        if [ "${#ENTRIES[@]}" -eq 0 ]; then
          dialog --msgbox "No entries to remove." 10 60
        else
          SELECT=$(dialog --menu "Select entry to remove:" 20 60 10 "${ENTRIES[@]}" 3>&1 1>&2 2>&3)
          [ -n "$SELECT" ] && sed -i "/^$SELECT|/d" "$CUSTOM_ENTRIES_FILE" && dialog --msgbox "Entry '$SELECT' removed." 10 60
        fi
        ;;
      "back"|"")
        break
        ;;
    esac
  done
}

system_menu() {
  while true; do
    SYS_CHOICE=$(dialog --clear --backtitle "System Tasks" --title "System Menu" --menu "Select an action:" 20 60 8 \
      "monitor" "System Monitor (btop)" \
      "network" "Manage Wi-Fi (nmtui)" \
      "reboot" "Reboot the system" \
      "shutdown" "Shutdown the system" \
      "timeshift" "Create/Restore System Snapshots" \
      "drives" "Mount/Unmount/Format Drives" \
      "display" "Display Settings (Resolution/Scaling)" \
      "back" "Return to Main Menu" 3>&1 1>&2 2>&3)

    case "$SYS_CHOICE" in
      "monitor")
        btop
        ;;
      "network")
        nmtui
        ;;
      "reboot")
        reboot
        ;;
      "shutdown")
        poweroff
        ;;
      "timeshift")
        timeshift_menu
        ;;
      "drives")
        drives_menu
        ;;
      "display")
        display_menu
        ;;
      "back"|"")
        break
        ;;
    esac
  done
}

drives_menu() {
  while true; do
    DRIVE_CHOICE=$(dialog --clear --backtitle "Drives" --title "Drives Menu" --menu "Select an action:" 15 60 4 \
      "mount" "Mount a Partition" \
      "unmount" "Unmount a Mounted Partition" \
      "format" "Format a Drive" \
      "back" "Back" 3>&1 1>&2 2>&3)

    case "$DRIVE_CHOICE" in
      "mount")
        mount_drive
        ;;
      "unmount")
        unmount_drive
        ;;
      "format")
        format_drive
        ;;
      "back"|"")
        break
        ;;
    esac
  done
}

mount_drive() {
  PARTITION_LIST=$(lsblk -pn -o NAME,RM,SIZE,MOUNTPOINT | awk '$2 == "1"')
  DEVICE=$(dialog --stdout --inputbox "Available partitions:\n\n$PARTITION_LIST\n\nEnter the partition to mount (e.g., /dev/sdb1):" 40 80)

  if [ -n "$DEVICE" ]; then
    MOUNTPOINT=$(dialog --stdout --inputbox "Enter mount point (e.g., /mnt):" 10 60)
    if [ -n "$MOUNTPOINT" ]; then
      mkdir -p "$MOUNTPOINT"
      if mount -t auto "$DEVICE" "$MOUNTPOINT"; then
        dialog --msgbox "Partition mounted at $MOUNTPOINT" 10 60
      else
        dialog --msgbox "Failed to mount $DEVICE at $MOUNTPOINT" 10 60
      fi
    else
      dialog --msgbox "No mount point entered." 10 60
    fi
  else
    dialog --msgbox "No partition entered." 10 60
  fi
}

unmount_drive() {
  PARTITION_LIST=$(lsblk -pn -o NAME,RM,SIZE,MOUNTPOINT | awk '$2 == "1"')
  MOUNTED_DRIVE=$(dialog --stdout --inputbox "Available partitions:\n\n$PARTITION_LIST\nEnter mount point (e.g., /mnt/usb):" 10 60)
    if umount -f "$MOUNTED_DRIVE"; then
      dialog --msgbox "Partition unmounted successfully." 10 60
    else
      dialog --msgbox "Failed to unmount." 10 60
    fi
}

format_drive() {
  # List available block devices (not partitions specifically, as formatting usually is at device or partition level)
  # Using lsblk to list non-mounted devices as candidates
  DEVICES=$(lsblk -pno NAME,SIZE,TYPE | grep 'disk\|part')
  SELECTED_DEVICE=$(echo "$DEVICES" | fzf --prompt="Select a device/partition to format: ")
  if [ -n "$SELECTED_DEVICE" ]; then
    DEVICE=$(echo "$SELECTED_DEVICE" | awk '{print $1}')
    FS_TYPE=$(dialog --clear --backtitle "Format Drive" --title "Select Filesystem" --menu "Select the filesystem to format with:" 15 60 3 \
      "fat32" "Format as FAT32" \
      "ntfs" "Format as NTFS" \
      "exfat" "Format as exFAT" 3>&1 1>&2 2>&3)

    if [ -n "$FS_TYPE" ]; then
      case "$FS_TYPE" in
        "fat32")
          mkfs.vfat -F 32 "$DEVICE" && dialog --msgbox "Device $DEVICE formatted as FAT32." 10 60 || dialog --msgbox "Formatting failed." 10 60
          ;;
        "ntfs")
          mkfs.ntfs -F "$DEVICE" && dialog --msgbox "Device $DEVICE formatted as NTFS." 10 60 || dialog --msgbox "Formatting failed." 10 60
          ;;
        "exfat")
          mkfs.exfat "$DEVICE" && dialog --msgbox "Device $DEVICE formatted as exFAT." 10 60 || dialog --msgbox "Formatting failed." 10 60
          ;;
      esac
    else
      dialog --msgbox "No filesystem type selected." 10 60
    fi
  else
    dialog --msgbox "No device selected." 10 60
  fi
}

timeshift_menu() {
  while true; do
    TS_CHOICE=$(dialog --clear --backtitle "Timeshift" --title "Timeshift Menu" --menu "Select an action:" 15 60 3 \
      "create" "Create a new system snapshot" \
      "restore" "Restore a system snapshot" \
      "back" "Back" 3>&1 1>&2 2>&3)

    case "$TS_CHOICE" in
      "create")
        dialog --infobox "Creating a new Timeshift snapshot..." 5 40
        timeshift --create --comments "Manual backup"
        dialog --msgbox "Snapshot created successfully." 10 60
        ;;
      "restore")
        timeshift --restore
        ;;
      "back"|"")
        break
        ;;
    esac
  done
}

display_menu() {
  while true; do
    DISP_CHOICE=$(dialog --clear --backtitle "Display Settings" --title "Display Menu" --menu "Select an action:" 15 60 3 \
      "change_resolution" "Change Resolution. Not persistent." \
      "scale_text" "Scale Console Text (setfont)" \
      "back" "Back" 3>&1 1>&2 2>&3)

    case "$DISP_CHOICE" in
      "change_resolution")
        change_resolution
        ;;
      "scale_text")
        scale_text
        ;;
      "back"|"")
        break
        ;;
    esac
  done
}

change_resolution() {
  RES=$(dialog --stdout --inputbox "Enter desired resolution (e.g., 1920x1080):" 10 60)
  if [ -n "$RES" ]; then
    XRES=$(echo "$RES" | cut -d'x' -f1)
    YRES=$(echo "$RES" | cut -d'x' -f2)
    if [ -n "$XRES" ] && [ -n "$YRES" ]; then
      if fbset -xres "$XRES" -yres "$YRES"; then
        dialog --msgbox "Resolution changed to ${XRES}x${YRES}." 10 60
      else
        dialog --msgbox "Failed to set resolution." 10 60
      fi
    else
      dialog --msgbox "Invalid resolution format." 10 60
    fi
  else
    dialog --msgbox "No resolution entered." 10 60
  fi
}

scale_text() {

  # Terminus fonts (Debian/Ubuntu):
  # - Lat15-Terminus12x6.psf.gz   (Small)
  # - Lat15-Terminus14.psf.gz     (Medium)
  # - Lat15-TerminusBold24x12.psf.gz     (Large)
  # - Lat15-TerminusBold32x16.psf.gz (Extra Large)
  
  FONT_MENU=(
    "small" "Small Font (12x6)"
    "medium" "Medium Font (14)"
    "large" "Large Font (Bold 24x12)"
    "xlarge" "Extra Large Font (Bold 32x16)"
  )
  
  FONT_CHOICE=$(dialog --clear --backtitle "Scale Text" --title "Select Text Size" --menu "Choose a font size:" 15 60 4 \
    "${FONT_MENU[@]}" 3>&1 1>&2 2>&3)
  
  case "$FONT_CHOICE" in
    "small")
	  FONT="/usr/share/consolefonts/Lat15-Terminus12x6.psf.gz"
      setfont "$FONT" && dialog --msgbox "Font changed to Small." 10 60
      echo "FONT=${FONT}" > /etc/default/console-setup
      dpkg-reconfigure -f noninteractive console-setup
      ;;
    "medium")
	  FONT="/usr/share/consolefonts/Lat15-Terminus14.psf.gz"
      setfont "$FONT" && dialog --msgbox "Font changed to Medium." 10 60
      echo "FONT=${FONT}" > /etc/default/console-setup
      dpkg-reconfigure -f noninteractive console-setup
      ;;
    "large")
      FONT="/usr/share/consolefonts/Lat15-TerminusBold24x12.psf.gz"
      setfont "$FONT" && dialog --msgbox "Font changed to Large." 10 60
      echo "FONT=${FONT}" > /etc/default/console-setup
      dpkg-reconfigure -f noninteractive console-setup
      ;;
    "xlarge")
	  FONT="/usr/share/consolefonts/Lat15-TerminusBold32x16.psf.gz"
      setfont "$FONT" && dialog --msgbox "Font changed to Extra Large." 10 60
      echo "FONT=${FONT}" > /etc/default/console-setup
      dpkg-reconfigure -f noninteractive console-setup
      ;;
    *)
      dialog --msgbox "No font size selected." 10 60
      ;;
  esac
}

main_menu
EOF

chmod +x /usr/local/bin/menu

echo "Creating command aliases..."
cat << 'EOF' > /etc/profile.d/aliases.sh
alias menu="menu"
alias file="mc"
alias browse="links2 -g"
EOF

echo "Configuring menu to run on login..."
if ! grep -q "menu" /etc/profile; then
  cat << 'EOF' >> /etc/profile
# Launch menu automatically on login (only if interactive shell)
if [ -n "$PS1" ]; then
  menu
fi
EOF
fi

echo "Cleaning up and finalizing..."
apt autoremove -y
apt clean

echo "Setup is complete!
- The menu will appear automatically when you log in as root.
- Type 'menu' to open the menu at any time.
"
setfont /usr/share/consolefonts/Lat15-TerminusBold24x12.psf.gz
echo "FONT=Lat15-TerminusBold24x12.psf.gz" > /etc/default/console-setup
dpkg-reconfigure -f noninteractive console-setup
menu
