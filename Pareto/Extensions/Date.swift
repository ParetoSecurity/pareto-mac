import Foundation

extension Date {
    public static let DayInMilis = (60 * 60 * 24 * 1000)
    public static let HourInMilis = (60 * 60 * 1000)

    func currentTimeMillis() -> Int {
        return Int(timeIntervalSince1970 * 1000)
    }

    static func fromTimeStamp(timeStamp: Int) -> Date {
        return NSDate(timeIntervalSince1970: TimeInterval(timeStamp / 1000)) as Date
    }

    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    func as3339String() -> String {
        let RFC3339DateFormatter = DateFormatter()
        RFC3339DateFormatter.locale = Locale(identifier: "en_US_POSIX")
        RFC3339DateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        RFC3339DateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        return RFC3339DateFormatter.string(from: self)
    }
}
