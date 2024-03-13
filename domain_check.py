#!/usr/bin/env python3

import re
import requests
import socket
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

    def check(self, domain: str, response: requests.Response) -> None:
        if response.status_code >= 500:
            print(domain + self.RED + ' had server side error: ' + str(response.status_code) + self.END)
        elif response.status_code < 500 and response.status_code >= 400:
            print(domain + self.RED + ' had client side error: ' + str(response.status_code) + self.END)
        else:
            warning: bool = False
            if len(response.history) >= 10:
                print(domain + self.YELLOW + ' responded but had 10 or more redirects.' + self.END)
                warning = True
            if socket.gethostbyname(domain) not in self.local_ips:
                print(domain + self.YELLOW + ' did not resolve to an internal ip.' + self.END)
                warning = True
            if not re.search(domain, response.url):
                print(domain + self.YELLOW + ' not contained in final redirect.' + self.END)
                warning = True
            if not warning:
                print(domain + self.GREEN + ' ok' + self.END)

    def run(self) -> None:
        domain: str
        for domain in self.domain_list:
            try:
                self.check(domain, requests.get(domain, timeout=5))
            except ConnectionError:
                try:
                    ip = socket.gethostbyname(domain)
                    print(domain + self.RED + ' located in ' + ip + ', did not respond.' + self.END)
                except socket.gaierror:
                    print(domain + self.RED + ' did not resolve.' + self.END)
            except requests.Timeout:
                print(domain + self.RED + ' did not respond in time.' + self.END)
            except requests.TooManyRedirects:
                print(domain + self.RED + ' had too many redirects.' + self.END)
