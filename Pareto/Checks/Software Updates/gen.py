#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
from string import Template
from pathlib import Path
from uuid import uuid5, NAMESPACE_URL
import re
import requests

current = Path(__file__).parent.resolve()
template = Template(current.joinpath("AppUpdateCheck.tmpl").read_text())

apps = set([
    "1Password 7",
    "Firefox",
    "Bitwarden",
    "Cyberduck",
    "Dashlane",
    "Docker",
    "Dropbox",
    "Enpass",
    "Firefox",
    "GitHub Desktop",
    "Google Chrome",
    "Hush",
    "iTerm",
    "LibreOffice",
    "Muzzle",
    "NordLayer",
    "Resilio Sync",
    "Signal",
    "Slack",
    "Sublime Text",
    "Tailscale",
    "Visual Studio Code",
    "WireGuard",
    "zoom.us",
])

possible_uuids = []

for app in apps:

    global_loc = Path(f"/Applications/{app}.app/Contents/Info.plist").resolve()
    user_loc = (
        Path(f"~/Applications/{app}.app/Contents/Info.plist").expanduser().resolve()
    )
    if not (global_loc.is_file() or user_loc.is_file()):
        continue

    full_path = str((global_loc if global_loc.is_file() else user_loc).absolute())
    safename = re.sub(r"\s", "", app)
    safename = re.sub(r"[\.\-\_]", "", safename)
    safenameclass = f"App{safename}Check"
    uuid = uuid5(NAMESPACE_URL, safename)
    print(f"{safename}={uuid}")
    filename = f"{safename}.swift"
    possible_uuids.append(uuid)
    print("\n\n")
    
    if current.joinpath(filename).is_file():
        continue

    SUFeedURL = (
        os.popen(f"/usr/libexec/PlistBuddy -c Print:SUFeedURL '{full_path}'")
        .read()
        .strip("\n")
    )
    bundle = (
        os.popen(f"/usr/libexec/PlistBuddy -c Print:CFBundleIdentifier '{full_path}'")
        .read()
        .strip("\n")
    )
    app_name = (
        os.popen(f"/usr/libexec/PlistBuddy -c Print:CFBundleName '{full_path}'")
        .read()
        .strip("\n")
    )

    if not SUFeedURL:
        try:
            app_store = requests.get(
                f"https://itunes.apple.com/lookup?bundleId={bundle}&country=us&entity=macSoftware&limit=1"
            )
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

    print(f"Adding {safenameclass} with uuid:{uuid} to {filename}")
    current.joinpath(filename).write_text(
        template.substitute(
            safename=safename,
            safenameclass=safenameclass,
            app=app,
            uuid=uuid,
            bundle=bundle,
            app_name=app_name,
            SUFeedURL=SUFeedURL,
        )
    )
    
print("\n\n")

for uuid in possible_uuids:
    print(
        f"""<permanent-redirect tal:omit-tag target="https://paretosecurity.com/check/{uuid}" />"""
    )
