import Foundation

extension Date {
    public static let DayInMilis = (60 * 60 * 24 * 1000)
    public static let HourInMilis = (60 * 60 * 1000)

    func currentTimeMillis() -> Int {
        return Int(timeIntervalSince1970 * 1000)
    }

    func fromTimeStamp(timeStamp: Int) -> String {
        let date = NSDate(timeIntervalSince1970: TimeInterval(timeStamp / 1000))

        let dayTimePeriodFormatter = DateFormatter()
        dayTimePeriodFormatter.dateFormat = "dd MMM YY, hh:mm a"

        let dateString = dayTimePeriodFormatter.string(from: date as Date)
        return dateString
    }
}
