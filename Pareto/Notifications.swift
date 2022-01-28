//
//  Notifications.swift
//  Pareto Security
//
//  Created by Janez Troha on 28/01/2022.
//

import Cocoa
import Defaults
import Foundation
import os.log
import UserNotifications

enum NotificationType: String {
    case Check = "CHECK_NOTICE"
}

enum NotificationAction: String {
    case MoreInfo = "MORE_INFO_ACTION"
}

func registerNotifications() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { _, error in

        if error != nil {
            let alert = NSAlert()
            alert.messageText = "You have to allow notifications access if you wish to receive notifications."
            alert.alertStyle = NSAlert.Style.informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    let moreAction = UNNotificationAction(identifier: NotificationAction.MoreInfo.rawValue,
                                          title: "More Info",
                                          options: [])
    // Define the notification type
    let checkCategory =
        UNNotificationCategory(identifier: NotificationType.Check.rawValue,
                               actions: [moreAction],
                               intentIdentifiers: [],
                               hiddenPreviewsBodyPlaceholder: "",
                               options: .customDismissAction)
    // Register the notification type.
    let notificationCenter = UNUserNotificationCenter.current()
    notificationCenter.setNotificationCategories([checkCategory])
}

func showNotification(check: ParetoCheck) {
    if !Defaults[.showNotifications] {
        os_log("Not showing notification, disabled")
        return
    }

    let content = UNMutableNotificationContent()
    content.title = "Check Failed"
    content.body = check.TitleOFF
    content.userInfo = ["CHECK_ID": check.UUID]
    content.categoryIdentifier = NotificationType.Check.rawValue

    if #available(macOS 12.0, *) {
        content.interruptionLevel = .critical
    }

    let request = UNNotificationRequest(identifier: check.UUID, content: content, trigger: nil)
    let center = UNUserNotificationCenter.current()
    center.add(request) { fn in
        os_log("Notification failed: %s", fn.debugDescription)
    }
}
