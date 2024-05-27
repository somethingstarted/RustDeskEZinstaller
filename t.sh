#!/bin/bash

# Variables
GITHUB_REPO="rustdesk/rustdesk"
DOWNLOAD_DIR="/tmp"
PKG_FILE="$DOWNLOAD_DIR/rustdesk_latest"
DEPENDENCIES=("curl")

# ANSI color codes
RESET="\e[0m"
BOLD="\e[1m"
UNDERLINE="\e[4m"
BLINK="\e[5m"
BLACK="\e[30m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
WHITE="\e[37m"

# Function to detect available package managers
detect_package_managers() {
    AVAILABLE_PKG_MANAGERS=()
    if command -v apt &> /dev/null; then
        AVAILABLE_PKG_MANAGERS+=("apt")
    fi
    if command -v dnf &> /dev/null; then
        AVAILABLE_PKG_MANAGERS+=("dnf")
    fi
    if command -v yum &> /dev/null; then
        AVAILABLE_PKG_MANAGERS+=("yum")
    fi
    if command -v pacman &> /dev/null; then
        AVAILABLE_PKG_MANAGERS+=("pacman")
    fi
    if command -v zypper &> /dev/null; then
        AVAILABLE_PKG_MANAGERS+=("zypper")
    fi
    if command -v flatpak &> /dev/null; then
        AVAILABLE_PKG_MANAGERS+=("flatpak")
    fi
}

# Function to check and inform missing dependencies
check_dependencies() {
    MISSING_DEPENDENCIES=()
    for DEP in "${DEPENDENCIES[@]}"; do
        if ! command -v "$DEP" &> /dev/null; then
            MISSING_DEPENDENCIES+=("$DEP")
        fi
    done

    if [ ${#MISSING_DEPENDENCIES[@]} -eq 0 ]; then
        echo -e "${GREEN}All necessary dependencies are installed.${RESET}"
    else
        echo -e "${RED}Missing dependencies:${RESET}"
        for DEP in "${MISSING_DEPENDENCIES[@]}"; do
            echo -e "${YELLOW}  $DEP${RESET}"
        done
        echo -e "${RED}Please install the missing dependencies and run the script again.${RESET}"
        exit 1
    fi
}

# Function to install selected package
install_package() {
    EXTENSION="${SELECTED_NAME##*.}"
    if [ "$(id -u)" -eq 0 ]; then
        SUDO=""
    else
        SUDO="sudo"
    fi

    case "$EXTENSION" in
        deb)
            if [ "$SELECTED_PKG_MANAGER" = "apt" ]; then
                echo -e "${CYAN}Installing $SELECTED_NAME with dpkg...${RESET}"
                $SUDO dpkg -i "$PKG_FILE"
                $SUDO apt-get install -f
            else
                echo -e "${RED}Unsupported package type for your system: $EXTENSION${RESET}"
                return 1
            fi
            ;;
        rpm)
            if [ "$SELECTED_PKG_MANAGER" = "dnf" ]; then
                echo -e "${CYAN}Installing $SELECTED_NAME with dnf...${RESET}"
                $SUDO dnf install -y "$PKG_FILE"
            elif [ "$SELECTED_PKG_MANAGER" = "yum" ]; then
                echo -e "${CYAN}Installing $SELECTED_NAME with yum...${RESET}"
                $SUDO yum install -y "$PKG_FILE"
            else
                echo -e "${RED}Unsupported package type for your system: $EXTENSION${RESET}"
                return 1
            fi
            ;;
        flatpak)
            if [ "$SELECTED_PKG_MANAGER" = "flatpak" ]; then
                echo -e "${CYAN}Installing $SELECTED_NAME with flatpak...${RESET}"
                $SUDO flatpak install -y "$PKG_FILE"
            else
                echo -e "${RED}Unsupported package type for your system: $EXTENSION${RESET}"
                return 1
            fi
            ;;
        AppImage)
            echo -e "${CYAN}Running $SELECTED_NAME...${RESET}"
            chmod +x "$PKG_FILE"
            "$PKG_FILE"
            ;;
        zst)
            if [ "$SELECTED_PKG_MANAGER" = "pacman" ]; then
                echo -e "${CYAN}Installing $SELECTED_NAME with pacman...${RESET}"
                $SUDO pacman -U --noconfirm "$PKG_FILE"
            else
                echo -e "${RED}Unsupported package type for your system: $EXTENSION${RESET}"
                return 1
            fi
            ;;
        *)
            echo -e "${RED}Unsupported file type: $EXTENSION${RESET}"
            return 1
            ;;
    esac
    return $?
}

# Detect available package managers
detect_package_managers

# Function to prompt user to select a package manager
select_package_manager() {
    while true; do
        echo -e "${GREEN}Available package managers:${RESET}"
        for i in "${!AVAILABLE_PKG_MANAGERS[@]}"; do
            echo -e "${GREEN}$((i+1)). ${AVAILABLE_PKG_MANAGERS[$i]}${RESET}"
        done
        echo -e "${RED}$(( ${#AVAILABLE_PKG_MANAGERS[@]} + 1 )). Nevermind, cancel${RESET}"

        read -p "Enter the number of the package manager you want to use: " PKG_MANAGER_CHOICE

        if ! [[ "$PKG_MANAGER_CHOICE" =~ ^[0-9]+$ ]] || [ "$PKG_MANAGER_CHOICE" -lt 1 ] || [ "$PKG_MANAGER_CHOICE" -gt $(( ${#AVAILABLE_PKG_MANAGERS[@]} + 1 )) ]; then
            echo -e "${RED}Invalid choice.${RESET}"
            continue
        fi

        if [ "$PKG_MANAGER_CHOICE" -eq $(( ${#AVAILABLE_PKG_MANAGERS[@]} + 1 )) ]; then
            echo -e "${YELLOW}Cancelled by user.${RESET}"
            exit 0
        fi

        SELECTED_PKG_MANAGER="${AVAILABLE_PKG_MANAGERS[$((PKG_MANAGER_CHOICE-1))]}"
        echo -e "${CYAN}Selected package manager: $SELECTED_PKG_MANAGER${RESET}"
        break
    done
}

# Initial selection of package manager
select_package_manager

# Check and inform missing dependencies
check_dependencies

while true; do
    # Fetch all available Linux download links from the latest release
    echo -e "${CYAN}Fetching release data from GitHub...${RESET}"
    RELEASE_DATA=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest")
    echo -e "${CYAN}Fetched release data.${RESET}"

    # Extract download URLs and names for relevant files
    DOWNLOAD_URLS=($(echo "$RELEASE_DATA" | grep -oP 'https://[^"]*' | grep -v '\.exe\|\.apk\|\.dmg\|\.zip\|\.tar\.gz' | grep -E '\.deb$|\.rpm$|\.AppImage$|\.flatpak$|\.pkg\.tar\.zst$'))
    DOWNLOAD_NAMES=($(echo "$RELEASE_DATA" | grep -oP '(?<="name": ")[^"]*' | grep -v '\.exe\|\.apk\|\.dmg\|\.zip\|\.tar\.gz' | grep -E '\.deb$|\.rpm$|\.AppImage$|\.flatpak$|\.pkg\.tar\.zst$'))

    # Display available downloads
    echo -e "${GREEN}Available downloads:${RESET}"
    for i in "${!DOWNLOAD_NAMES[@]}"; do
        echo -e "${GREEN}$((i+1)). ${DOWNLOAD_NAMES[$i]}${RESET}"
    done
    echo -e "${YELLOW}$(( ${#DOWNLOAD_NAMES[@]} + 1 )). Go back to change package manager${RESET}"
    echo -e "${RED}$(( ${#DOWNLOAD_NAMES[@]} + 2 )). Nevermind, cancel${RESET}"

    # Prompt the user for the download choice
    read -p "Enter the number of the download you want to use: " USER_CHOICE

    # Validate user choice
    if ! [[ "$USER_CHOICE" =~ ^[0-9]+$ ]] || [ "$USER_CHOICE" -lt 1 ] || [ "$USER_CHOICE" -gt $(( ${#DOWNLOAD_NAMES[@]} + 2 )) ]; then
        echo -e "${RED}Invalid choice.${RESET}"
        continue
    fi

    if [ "$USER_CHOICE" -eq $(( ${#DOWNLOAD_NAMES[@]} + 1 )) ]; then
        select_package_manager
        continue
    fi

    if [ "$USER_CHOICE" -eq $(( ${#DOWNLOAD_NAMES[@]} + 2 )) ]; then
        echo -e "${YELLOW}Cancelled by user.${RESET}"
        exit 0
    fi

    # Download the selected file
    SELECTED_URL="${DOWNLOAD_URLS[$((USER_CHOICE-1))]}"
    SELECTED_NAME="${DOWNLOAD_NAMES[$((USER_CHOICE-1))]}"
    echo -e "${CYAN}Downloading $SELECTED_NAME...${RESET}"
    curl -L -o "$PKG_FILE" "$SELECTED_URL"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Download failed.${RESET}"
        continue
    fi
    echo -e "${CYAN}Downloaded $SELECTED_NAME.${RESET}"

    # Install the selected package
    install_package
    if [ $? -ne 0 ]; then
        echo -e "${RED}Installation failed.${RESET}"
        continue
    fi

    echo -e "${GREEN}RustDesk has been updated to the latest version.${RESET}"
    break
done
