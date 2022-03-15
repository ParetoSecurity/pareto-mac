#!/bin/bash

# enable firewall
sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1
sudo defaults write /Library/Preferences/com.apple.alf stealthenabled -int 1

# enable updates
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -int 1
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -int 1
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -int 1

# system
# sudo systemsetup -setremotelogin off
# sudo systemsetup -setremoteappleevents off

# sharing
# 2 - File Sharing
# 3 - Media Sharing
# 4 - Printer Sharing
# 6 - Remote managment

#osascript -e '
# tell application "System Preferences" to reveal the anchor named "Services_RemoteAppleEvent" of pane id "com.apple.preferences.sharing"
# tell application "System Events"
# 	tell process "System Preferences"
# 		repeat until exists window "Sharing"
# 			delay 0.5
# 		end repeat
# 		click button "Click the lock to make changes." of window "Sharing"
# 	end tell
# 	repeat until exists window 1 of process "SecurityAgent"
# 		delay 0.5
# 	end repeat
# 	tell process "SecurityAgent"
# 		tell window 1
# 			click button "OK" of group 2
# 		end tell
# 	end tell
# end tell
# tell application "System Events" to tell process "System Preferences"
#     click checkbox 1 of row 2 of table 1 of scroll area 1 of group 1 of window "Sharing"
# end tell
# tell application "System Events" to tell process "System Preferences"
#     click checkbox 1 of row 4 of table 1 of scroll area 1 of group 1 of window "Sharing"
# end tell
# tell application "System Events" to tell process "System Preferences"
#     click checkbox 1 of row 6 of table 1 of scroll area 1 of group 1 of window "Sharing"
# end tell
# '
