//
//  Screensaver.swift
//  Pareto Security
//
//  Created by Janez Troha on 19/07/2021.
//
import Foundation

class PasswordAfterSleepCheck: ParetoCheck {
    static let sharedInstance = PasswordAfterSleepCheck()
    override var UUID: String {
        "37dee029-605b-4aab-96b9-5438e5aa44d8"
    }

    override var TitleON: String {
        "Password after sleep or screensaver is on"
    }

    override var TitleOFF: String {
        "Password after sleep or screensaver is off"
    }

    override var CIS: String {
        "1-5.8"
    }

    @objc func getGracePeriod() -> Int {
        // credit Victor Vrantchan
        let handle = dlopen(
            "/System/Library/PrivateFrameworks/MobileKeyBag.framework/Versions/Current/MobileKeyBag",
            RTLD_LAZY
        )
        let symbol = dlsym(handle, "MKBDeviceGetGracePeriod")
        typealias GetterFunction = @convention(c) (Any?) -> NSDictionary
        let MKBDeviceGetGracePeriod = unsafeBitCast(symbol, to: GetterFunction.self)
        let x = MKBDeviceGetGracePeriod([:])
        return x["GracePeriod"] as? Int ?? 0
    }

    override func checkPasses() -> Bool {
        let out = getGracePeriod()
        return out > 0 && out <= 60 * 15
    }
}
