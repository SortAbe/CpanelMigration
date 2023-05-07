cPanel Migration Script Readme
Overview

This script helps you collect and display important information about your cPanel server before migration. It checks the operating system, installed software, accounts, domains, and databases on your server.
Prerequisites

    The script must be run as the root user
    cPanel must be installed

Usage

    Copy the entire script into a new file, e.g., cpanel_migration.sh.
    Make the script executable: chmod +x cpanel_migration.sh
    Run the script: ./cpanel_migration.sh

Output

The script will generate a detailed report with the following sections:

    Operating System
    Virtual Machine Detection
    Installed Tools
    Drive Stats
    Software Versions
    Domains
    Databases

All the data will be stored in a directory named ~/migration-<DATE>.
Notes

This script is a work in progress, and there are some TODO items that are not yet implemented, such as checking for leftover partitions, MySQL governor, and CageFS account information.
