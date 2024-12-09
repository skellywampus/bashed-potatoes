# Bashed Potatoes

**Bashed Potatoes** is a minimal, menu-driven environment for Debian-based systems. It provides a user-friendly, text-based interface for managing common system tasks without relying heavily on manual command-line work. After setup, the system automatically logs in as root and presents a menu from which you can manage packages, browse the web, open a file manager, monitor the system, manage drives, customize menu entries, create and restore Timeshift snapshots, and more.

## Features

- **Automatic Login as Root:**  
  Once set up, the system boots straight into a root session with the custom menu.
  
- **User-Friendly Menu Interface:**  
  Powered by `dialog` and `fzf`, the menu is navigable with arrow keys and simple prompts.
  
- **No Need to Memorize Commands:**  
  Manage packages (APT), mount/unmount drives, adjust Wi-Fi networks (via `nmtui`), and run Timeshift snapshots without typing complex commands.
  
- **Easily Customize the Menu:**  
  Add or remove custom entries on-the-fly. Integrate your own shortcuts or scripts into the menu system.

- **Timeshift Integration:**  
  Create and restore system snapshots directly from the menu, ensuring easy system recovery points.

- **Run Shell Commands:**  
  If needed, there's an option to run arbitrary shell commands directly from the menu.

## Dependencies & Requirements

- A minimal Debian (or compatible) installation.
- Root or sudo privileges to run the setup script initially.
- Internet access during initial setup to install required packages.
  
**Installed Packages Include:**
- `dialog`, `fzf` for menu interface
- `mc` (Midnight Commander) for file management
- `links2` for web browsing
- `network-manager` and `nmtui` for network configuration
- `btop` for system monitoring
- `timeshift` for system snapshots
- `ncdu` for disk usage analysis
- `tldr` for quick command examples

## Setup Instructions

1. **Start from a Minimal Debian System:**  
   Install a fresh minimal Debian system or a Debian-based VM.

2. **Obtain the Script:**  
   Clone this repository:
   ``bash``
   ``git clone https://github.com/skellywampus/bashed-potatoes.git``
   ``cd bashed-potatoes``

3. **Run the Setup Script as Root:**

    ``sudo ./setup_script.sh``

    You will be prompted to:
        Set the root password

    Follow the on-screen prompts.

    ##Reboot:##
    After the script finishes, on reboot, the system will automatically log you in as root and present the Bashed Potatoes menu.

## Usage

   **Navigation:**
    Use the arrow keys and Enter to choose options. Pressing ESC or selecting "back" returns you to the previous menu.

   **Running Programs:**
    When you select an option (e.g., file), it launches the program. Exiting programs returns you to the menu.

   **Managing Drives:**
    Under system -> drives, you can view a list of partitions and manually type in the partition and mount point to mount, or choose a mounted partition to unmount.

   **APT Management:**
    Under apt, you can update, install, and remove packages from a menu interface.

   **Customization:**
    Under customize, add your own menu entries or remove existing custom entries.

   **Timeshift Snapshots:**
    Under system -> timeshift, create or restore system snapshots easily.

   **Exit to Terminal:**
    Selecting exit from the main menu returns you to a standard root shell.

## Removing the Menu System

If you later decide you don't want this environment, select the "remove_menu" option (if present) or remove files manually (such as /usr/local/bin/menu, /etc/profile.d/aliases.sh, and the lines added to /etc/profile). Also restore your /etc/systemd/system/getty@tty1.service.d/override.conf to remove autologin.
License

## License

This project uses various open-source tools (Debian packages, GNU utilities), each under their respective licenses (GPL, MIT, etc.). Consult Debian’s repositories and Timeshift’s documentation for license details. The custom setup script and menu definitions can be considered under the MIT License, unless otherwise specified.

Enjoy your fresh, minimal, menu-driven Debian environment – Bashed Potatoes!
