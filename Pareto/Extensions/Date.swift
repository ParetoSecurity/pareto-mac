import Foundation

extension Date {
    func currentTimeMillis() -> Int64 {
        return Int64(timeIntervalSince1970 * 1000)
    }

    func fromTimeStamp(timeStamp: Int) -> String {
        let date = NSDate(timeIntervalSince1970: TimeInterval(timeStamp / 1000))

        let dayTimePeriodFormatter = DateFormatter()
        dayTimePeriodFormatter.dateFormat = "dd MMM YY, hh:mm a"

        let dateString = dayTimePeriodFormatter.string(from: date as Date)
        return dateString
    }
}
