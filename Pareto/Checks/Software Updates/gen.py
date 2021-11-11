from string import Template
from pathlib import Path
from uuid import uuid5, NAMESPACE_URL
import re

template = Template(Path("AppUpdateCheck.tmpl").read_text())

apps = [
    "1Password 7",
    "Docker",
    "Dropbox",
    "Firefox",
    "GitHub Desktop",
    "Google Chrome",
    "LibreOffice",
    "NordLayer",
    "Resilio Sync",
    "Safari",
    "Signal",
    "Slack",
    "Sublime Text",
    "Visual Studio Code",
    "zoom.us",
]

for app in apps:
    safename = re.sub(r'\s', '', app)
    safename = re.sub(r'[\.\-\_]', '', safename)
    safenameclass = f"App{safename}Check"
    uuid = uuid5(NAMESPACE_URL, safename)
    path = f"{safename}.swift"
    print(f"Adding {safenameclass} with uuid:{uuid} to {path}")
    Path(path).write_text(
        template.substitute(
            safename=safename, safenameclass=safenameclass, app=app, uuid=uuid
        )
    )
