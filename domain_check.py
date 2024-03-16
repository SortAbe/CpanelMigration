#!/usr/bin/env python3

import re
import requests
import socket
import ssl
import subprocess
import urllib3

from datetime import datetime, timedelta
from http import HTTPStatus
from typing import List

class Domain_checker:

    RED: str = '\033[91m'
    GREEN: str = '\033[92m'
    YELLOW: str = '\033[93m'
    END: str = '\033[0m'
    domain_list: List[str] = []
    local_ips: List[str] = []

    def __init__(self, local_ips: List[str], domain_list: List[str]) -> None:
        self.domain_list = domain_list
        self.local_ips = local_ips
        urllib3.disable_warnings()
        try:
            requests.packages.urllib3.disable_warnings(requests.packages.urllib3.exceptions.InsecureRequestWarning)
        except:
            return

    def log(self, message: str) -> None:
        with open('domains.log', 'a') as file:
            file.write(message + '\n')

    def write(self, domain: str) -> None:
        with open('domains.final', 'a') as file:
            match = re.search(r'(https?://)([^/]+)(/?.*)', domain)
            if match:
                 host: str = match.group(2)
            else:
                return
            file.write(host + '\n')

    def verify_ssl(self, domain: str) -> None:
        match = re.search(r'(https://)([^/]+)(/?.*)', domain)
        if match:
             host: str = match.group(2)
        else:
            return
        context = ssl.create_default_context()
        with socket.create_connection((host, 443)) as sock:
            with context.wrap_socket(sock, server_hostname=host) as secure_sock:
                secure_sock.do_handshake()
                cert = secure_sock.getpeercert()
                if cert:
                    if cert['issuer'] == cert['subject']:
                        message: str = (domain + self.YELLOW + ' SSL is self signed.' + self.END)
                        print(message)
                        self.log(message)
                    exipration = datetime.strptime(str(cert['notAfter']), '%b %d %H:%M:%S %Y %Z')
                    if datetime.now() > exipration - timedelta(days=30):
                        message: str = (domain + self.YELLOW + ' SSL will expire in less than 30 days.' + self.END)
                        print(message)
                        self.log(message)

    def check(self, domain: str, response: requests.Response) -> None:
        code: int = response.status_code
        if code >= 500:
            message: str = (domain + self.RED + ' had server side error: ' + str(code) + ' ' + HTTPStatus(code).phrase + self.END)
            print(message)
            self.log(message)
        elif code < 500 and code >= 400:
            message: str = (domain + self.RED + ' had client side error: ' + str(code) + ' ' + HTTPStatus(code).phrase + self.END)
            print(message)
            self.log(message)
        else:
            warning: bool = False
            self.write(response.url)
            if len(response.history) >= 10:
                message: str = (domain + self.YELLOW + ' responded but had 10 or more redirects.' + self.END)
                print(message)
                self.log(message)
                warning = True
            if socket.gethostbyname(domain) not in self.local_ips:
                message: str = (domain + self.YELLOW + ' did not resolve to an internal ip.' + self.END)
                print(message)
                self.log(message)
                warning = True
            if not re.search(domain, response.url):
                message: str = (domain + self.YELLOW + ' not contained in final redirect.' + self.END)
                print(message)
                self.log(message)
                warning = True
            if 'https' in response.url:
                try:
                    self.verify_ssl(response.url)
                except:
                    message: str = (domain + self.RED + ' SSL verification error.' + self.END)
                    print(message)
                    self.log(message)
                    warning = True
            if not warning:
                message: str = (domain + self.GREEN + ' ok' + self.END)
                self.log(message)

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
                    self.log(message)
                except socket.gaierror:
                    message: str = (domain + self.RED + ' did not resolve.' + self.END)
                    print(message)
                    self.log(message)
            except requests.Timeout:
                message: str = (domain + self.RED + ' did not respond in time.' + self.END)
                print(message)
                self.log(message)
            except requests.TooManyRedirects:
                message: str = (domain + self.RED + ' had too many redirects.' + self.END)
                print(message)
                self.log(message)

if __name__ == '__main__':
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
