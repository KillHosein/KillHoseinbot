#!/bin/bash

# Professional VPN Bot Manager
# Created for Professional Management

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SERVICE_BOT="vpn-bot"
SERVICE_WEB="vpn-webapp"
GITHUB_REPO="https://github.com/KillHosein/KillHoseinbot"

# Helper Functions
print_header() {
    clear
    echo -e "${CYAN}=================================================================${NC}"
    echo -e "${CYAN}             Professional VPN Bot Manager                        ${NC}"
    echo -e "${CYAN}=================================================================${NC}"
    echo ""
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Error: Please run as root (sudo ./manager.sh)${NC}"
        exit 1
    fi
}

press_enter() {
    echo ""
    read -p "Press Enter to continue..."
}

# ------------------------------------------------------------------
# Menu Actions
# ------------------------------------------------------------------

install_bot() {
    print_header
    echo -e "${YELLOW}>> Install / Re-install Bot${NC}"
    echo -e "${BLUE}This will install dependencies, configure the bot, and set up the service.${NC}"
    echo ""
    
    read -p "Are you sure you want to proceed? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then return; fi

    # Check if we are in the repo (installer.sh exists)
    if [ -f "$PROJECT_DIR/installer.sh" ]; then
        bash "$PROJECT_DIR/installer.sh"
    else
        # Bootstrap mode: Clone from GitHub
        echo -e "${YELLOW}installer.sh not found in current directory.${NC}"
        echo -e "${BLUE}Initiating download from GitHub...${NC}"
        
        # Check/Install Git
        if ! command -v git &> /dev/null; then
            echo -e "${YELLOW}Installing Git...${NC}"
            apt-get update && apt-get install -y git
        fi

        # Get Repo URL
        echo -e "${CYAN}Please enter your GitHub Repository URL:${NC}"
        echo -e "(Press Enter to use default: $GITHUB_REPO)"
        read -p "Repo URL: " input_url
        repo_url=${input_url:-$GITHUB_REPO}

        if [[ "$repo_url" == *"YOUR_USERNAME"* ]]; then
             echo -e "${RED}Error: Invalid Repository URL. Please update the script or enter a valid URL.${NC}"
             press_enter
             return
        fi

        # Clone
        echo -e "${BLUE}Cloning into vpn-bot...${NC}"
        if [ -d "vpn-bot" ]; then
            echo -e "${YELLOW}Directory 'vpn-bot' already exists. Backing up...${NC}"
            mv vpn-bot "vpn-bot-backup-$(date +%s)"
        fi
        
        git clone "$repo_url" vpn-bot
        
        if [ -d "vpn-bot" ]; then
            cd vpn-bot
            chmod +x installer.sh manager.sh update.sh
            echo -e "${GREEN}Repository cloned successfully.${NC}"
            echo -e "${YELLOW}Starting installer...${NC}"
            sleep 2
            bash installer.sh
        else
            echo -e "${RED}Failed to clone repository. Please check the URL and internet connection.${NC}"
        fi
    fi
    press_enter
}

update_bot() {
    print_header
    echo -e "${YELLOW}>> Update Bot${NC}"
    echo -e "${BLUE}This will pull the latest changes from GitHub and restart the bot.${NC}"
    echo ""

    # Execute the existing update script if it exists
    if [ -f "$PROJECT_DIR/update.sh" ]; then
        bash "$PROJECT_DIR/update.sh"
    else
        # Fallback update logic
        echo -e "${YELLOW}update.sh not found. Using standard update procedure...${NC}"
        
        # Check internet
        wget -q --spider http://github.com
        if [ $? -ne 0 ]; then
            echo -e "${RED}No internet connection.${NC}"
            press_enter
            return
        fi

        echo -e "${BLUE}Pulling from GitHub...${NC}"
        git fetch --all
        git reset --hard origin/main
        
        echo -e "${BLUE}Updating dependencies...${NC}"
        if [ -f "requirements.txt" ]; then
            pip3 install -r requirements.txt
        fi

        echo -e "${BLUE}Restarting services...${NC}"
        systemctl restart $SERVICE_BOT
        systemctl restart $SERVICE_WEB
        
        echo -e "${GREEN}Update completed successfully!${NC}"
    fi
    press_enter
}

delete_bot() {
    print_header
    cd "$PROJECT_DIR" || return
    echo -e "${RED}>> Delete / Uninstall Bot${NC}"
    echo -e "${RED}WARNING: This will stop services, remove them, and delete files!${NC}"
    echo ""
    
    read -p "Type 'DELETE' to confirm uninstallation: " confirm
    if [[ "$confirm" != "DELETE" ]]; then
        echo -e "${YELLOW}Operation cancelled.${NC}"
        press_enter
        return
    fi

    echo -e "${YELLOW}Stopping services...${NC}"
    systemctl stop $SERVICE_BOT
    systemctl stop $SERVICE_WEB
    systemctl disable $SERVICE_BOT
    systemctl disable $SERVICE_WEB
    
    rm -f /etc/systemd/system/$SERVICE_BOT.service
    rm -f /etc/systemd/system/$SERVICE_WEB.service
    
    # Remove nginx config
    if [ -f "/etc/nginx/sites-enabled/vpn_bot" ]; then
        echo -e "${YELLOW}Removing Nginx config...${NC}"
        rm -f /etc/nginx/sites-enabled/vpn_bot
        rm -f /etc/nginx/sites-available/vpn_bot
        systemctl restart nginx
    fi
    
    systemctl daemon-reload

    echo -e "${YELLOW}Removing files...${NC}"
    # Ask before deleting the directory
    read -p "Do you want to delete the bot files in $PROJECT_DIR? (y/n): " del_files
    if [[ "$del_files" == "y" ]]; then
        # Be careful not to delete root or something wrong
        if [[ "$PROJECT_DIR" != "/" ]] && [[ "$PROJECT_DIR" != "$HOME" ]]; then
            rm -rf "$PROJECT_DIR"/*
            echo -e "${GREEN}Files removed.${NC}"
        else
            echo -e "${RED}Safety check: Cannot delete root or home directory! Please delete files manually.${NC}"
        fi
    else
        echo -e "${BLUE}Files kept.${NC}"
    fi

    echo -e "${GREEN}Uninstallation complete.${NC}"
    press_enter
    exit 0
}

service_menu() {
    while true; do
        print_header
        echo -e "${YELLOW}>> Service Management${NC}"
        echo "1) Start All Services"
        echo "2) Stop All Services"
        echo "3) Restart All Services"
        echo "4) Status (Bot)"
        echo "5) Status (WebApp)"
        echo "6) Back to Main Menu"
        echo ""
        read -p "Select an option [1-6]: " choice

        case $choice in
            1) 
                systemctl start $SERVICE_BOT
                systemctl start $SERVICE_WEB
                echo -e "${GREEN}Services started.${NC}"
                press_enter 
                ;;
            2) 
                systemctl stop $SERVICE_BOT
                systemctl stop $SERVICE_WEB
                echo -e "${RED}Services stopped.${NC}"
                press_enter 
                ;;
            3) 
                systemctl restart $SERVICE_BOT
                systemctl restart $SERVICE_WEB
                echo -e "${GREEN}Services restarted.${NC}"
                press_enter 
                ;;
            4) systemctl status $SERVICE_BOT; press_enter ;;
            5) systemctl status $SERVICE_WEB; press_enter ;;
            6) return ;;
            *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

view_logs() {
    while true; do
        print_header
        echo -e "${YELLOW}>> View Logs${NC}"
        echo "1) Bot Logs"
        echo "2) WebApp Logs"
        echo "3) Back"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) journalctl -u $SERVICE_BOT -f ;;
            2) journalctl -u $SERVICE_WEB -f ;;
            3) return ;;
            *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# ------------------------------------------------------------------
# Main Logic
# ------------------------------------------------------------------

check_root
chmod +x installer.sh update.sh 2>/dev/null

while true; do
    print_header
    echo "1) Install Bot (Setup)"
    echo "2) Update Bot (GitHub)"
    echo "3) Delete Bot (Uninstall)"
    echo "4) Service Management"
    echo "5) View Logs"
    echo "0) Exit"
    echo ""
    read -p "Select an option [0-5]: " choice

    case $choice in
        1) install_bot ;;
        2) update_bot ;;
        3) delete_bot ;;
        4) service_menu ;;
        5) view_logs ;;
        0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
    esac
done
