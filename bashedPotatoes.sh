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
PACKAGES="network-manager links2 mc feh btop util-linux fzf tldr mpv ncdu adduser timeshift"
echo "Installing required dependencies..."
apt install -y $PACKAGES || { echo "Failed to install required packages: $PACKAGES"; exit 1; }

# Check commands are installed
for cmd in dialog fzf feh mpv btop nano mc nmtui links2 tldr ncdu adduser timeshift; do
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
        [ -n "$CMD" ] && eval "$CMD" || dialog --msgbox "No command entered." 10 60
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
    SYS_CHOICE=$(dialog --clear --backtitle "System Tasks" --title "System Menu" --menu "Select an action:" 20 60 7 \
      "monitor" "System Monitor (btop)" \
      "network" "Manage Wi-Fi (nmtui)" \
      "reboot" "Reboot the system" \
      "shutdown" "Shutdown the system" \
      "timeshift" "Create/Restore System Snapshots" \
      "drives" "Mount/Unmount Drives" \
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
      "back"|"")
        break
        ;;
    esac
  done
}

drives_menu() {
  while true; do
    DRIVE_CHOICE=$(dialog --clear --backtitle "Drives" --title "Drives Menu" --menu "Select an action:" 15 60 3 \
      "mount" "Mount a Partition" \
      "unmount" "Unmount a Mounted Partition" \
      "back" "Back" 3>&1 1>&2 2>&3)

    case "$DRIVE_CHOICE" in
      "mount")
        mount_drive
        ;;
      "unmount")
        unmount_drive
        ;;
      "back"|"")
        break
        ;;
    esac
  done
}

mount_drive() {
  PARTITION_LIST=$(lsblk -pn -o NAME,SIZE,TYPE,MOUNTPOINT)
  DEVICE=$(dialog --stdout --inputbox "Available partitions:\n\n$PARTITION_LIST\n\nEnter the partition to mount (e.g., /dev/sdb1):" 20 80)

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
  MOUNTED_DRIVE=$(lsblk -p -o NAME,MOUNTPOINT | grep '/' | grep -v 'boot' | fzf --prompt="Select a mounted partition to unmount: ")
  if [ -n "$MOUNTED_DRIVE" ]; then
    MOUNTPOINT=$(echo "$MOUNTED_DRIVE" | awk '{print $2}')
    if [ -n "$MOUNTPOINT" ]; then
      if umount "$MOUNTPOINT"; then
        dialog --msgbox "Partition at $MOUNTPOINT unmounted successfully." 10 60
      else
        dialog --msgbox "Failed to unmount $MOUNTPOINT." 10 60
      fi
    fi
  else
    dialog --msgbox "No mounted partition selected." 10 60
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