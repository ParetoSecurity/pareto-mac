#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
from string import Template
from pathlib import Path
from uuid import uuid5, NAMESPACE_URL
import re
import requests

template = Template(Path("AppUpdateCheck.tmpl").read_text())

apps = [
    "1Password 7",
    "Bitwarden",
    "Cyberduck",
    "Docker",
    "Dropbox",
    "Firefox",
    "GitHub Desktop",
    "Google Chrome",
    "LibreOffice",
    "NordLayer",
    "Resilio Sync",
    "Signal",
    "Slack",
    "Sublime Text",
    "Visual Studio Code",
    "zoom.us",
    "Tailscale",
    "Hush",
    "Muzzle",
    "WireGuard",
    "Dashlane",
    "Enpass",
]

for app in apps:
    safename = re.sub(r'\s', '', app)
    safename = re.sub(r'[\.\-\_]', '', safename)
    safenameclass = f"App{safename}Check"
    uuid = uuid5(NAMESPACE_URL, safename)
    path = f"{safename}.swift"

    SUFeedURL = os.popen(f"/usr/libexec/PlistBuddy -c Print:SUFeedURL '/Applications/{app}.app/Contents/Info.plist'").read().strip("\n")
    bundle = os.popen(f"/usr/libexec/PlistBuddy -c Print:CFBundleIdentifier '/Applications/{app}.app/Contents/Info.plist'").read().strip("\n")
    app_name = os.popen(f"/usr/libexec/PlistBuddy -c Print:CFBundleName '/Applications/{app}.app/Contents/Info.plist'").read().strip("\n")
    
    if not SUFeedURL:
        try:
            app_store = requests.get(f"https://itunes.apple.com/lookup?bundleId={bundle}&country=us&entity=macSoftware&limit=1")
            app_store.raise_for_status()
            data = app_store.json()["results"][0]
            devices = data.get("supportedDevices", [])
            # Catalyst apps
            if devices and "MacDesktop-MacDesktop" not in data["supportedDevices"]:
                print(f"{app} is not supported via app store")
                continue
        except Exception:
            print(f"{app} is not supported")
            continue
        
    print(f"Adding {safenameclass} with uuid:{uuid} to {path}")
    Path(path).write_text(
        template.substitute(
            safename=safename,
            safenameclass=safenameclass,
            app=app,
            uuid=uuid,
            bundle=bundle,
            app_name=app_name,
            SUFeedURL=SUFeedURL
        )
    )
