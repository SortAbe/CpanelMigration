cPanel Migration Script Readme

Overview

This script helps you collect and display important information about your cPanel server before migration. It checks the operating system, installed software, accounts, domains, and databases on your server.
Prerequisites

    The script must be run as the root user
    cPanel must be installed
    Ptyhon3.6+
    Python3 requests library

Usage

    Verify you have Python3.6 + installed
    Verify that requests library is installed for Python3
    Run the script: bash mig.sh

Output

The script will generate a detailed report with the following sections:

    Operating System
    Virtual Machine Detection
    Drive Stats
    Software Versions
    Domains resolution
    Databases resolution

All the data logged will be stored in a directory named ./migration-DATE.
