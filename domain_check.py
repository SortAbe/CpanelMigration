#!/usr/bin/env python3

import certifi
import re
import requests
import socket
import ssl
import subprocess
import urllib3
from typing import Dict, List

class Domain_checker:

    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    END = '\033[0m'
    domain_list: List[str] = []
    domain_list_respone: Dict[str, List[str]] = {}
    local_ips: List[str] = []

    def __init__(self, local_ips: List[str], domain_list: List[str]) -> None:
        self.domain_list = domain_list
        self.local_ips = local_ips
        urllib3.disable_warnings()

    def write(self, message: str) -> None:
        with open('domain.log', 'a') as file:
            file.write(message + '\n')

    def verify_ssl(self, domain: str) -> None:
        match = re.search(r'(https://)([^/]+)(/?.*)', domain)
        if match:
            host = match.group(2)
        else:
            return
        context = ssl.create_default_context(cafile=certifi.where())
        with socket.create_connection((host, 443)) as sock:
            with context.wrap_socket(sock, server_hostname=host) as secure_sock:
                secure_sock.do_handshake()
                cert = secure_sock.getpeercert()
                if cert:
                    print(cert.values())

    def check(self, domain: str, response: requests.Response) -> None:
        if response.status_code >= 500:
            message: str = (domain + self.RED + ' had server side error: ' + str(response.status_code) + self.END)
            print(message)
            self.write(message)
        elif response.status_code < 500 and response.status_code >= 400:
            message: str = (domain + self.RED + ' had client side error: ' + str(response.status_code) + self.END)
            print(message)
            self.write(message)
        else:
            warning: bool = False
            if len(response.history) >= 10:
                message: str = (domain + self.YELLOW + ' responded but had 10 or more redirects.' + self.END)
                print(message)
                self.write(message)
                warning = True
            if socket.gethostbyname(domain) not in self.local_ips:
                message: str = (domain + self.YELLOW + ' did not resolve to an internal ip.' + self.END)
                print(message)
                self.write(message)
                warning = True
            if not re.search(domain, response.url):
                message: str = (domain + self.YELLOW + ' not contained in final redirect.' + self.END)
                print(message)
                self.write(message)
                warning = True
            if 'https' in response.url:
                try:
                    self.verify_ssl(response.url)
                except:
                    message: str = (domain + self.YELLOW + ' SSL verification error.' + self.END)
                    print(message)
                    self.write(message)
                    warning = True
            if not warning:
                message: str = (domain + self.GREEN + ' ok' + self.END)
                print(message)
                self.write(message)

    def run(self) -> None:
        domain: str
        for domain in self.domain_list:
            try:
                self.check(domain, requests.get('http://' + domain, timeout=5, verify=False))
            except ConnectionError:
                try:
                    ip = socket.gethostbyname(domain)
                    message: str = (domain + self.RED + ' located in ' + ip + ', did not respond.' + self.END)
                    print(message)
                    self.write(message)
                except socket.gaierror:
                    message: str = (domain + self.RED + ' did not resolve.' + self.END)
                    print(message)
                    self.write(message)
            except requests.Timeout:
                message: str = (domain + self.RED + ' did not respond in time.' + self.END)
                print(message)
                self.write(message)
            except requests.TooManyRedirects:
                message: str = (domain + self.RED + ' had too many redirects.' + self.END)
                print(message)
                self.write(message)

if __name__ == "__main__":
    domain_list: List[str] = []
    local_ips: List[str] = []
    lines: List[str] = subprocess.check_output(['whmapi1', 'get_domain_info']).decode().split('\n')
    for line in lines:
        line: str = line.strip()
        if 'domain:' in line:
            domain: str = line.split(' ')[1].strip()
            if domain not in domain_list:
                domain_list.append(domain)
        if 'ipv4:' in line:
            ip: str = line.split(' ')[1].strip()
            if ip not in local_ips:
                local_ips.append(ip)
    checker = Domain_checker(domain_list=domain_list, local_ips=local_ips)
    checker.run()
