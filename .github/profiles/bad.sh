#!/bin/bash

set -xe

# disable firewall
sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 0
sudo defaults write /Library/Preferences/com.apple.alf stealthenabled -int 0

# disable updates
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -int 0
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -int 0
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -int 0

# system
sudo systemsetup -setremotelogin on
sudo systemsetup -setremoteappleevents on