import Foundation

extension Date {
    var flooredToHour: Date {
        let seconds = timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: (seconds / 3600).rounded(.down) * 3600)
    }

    func addingHours(_ hours: Int) -> Date {
        addingTimeInterval(Double(hours) * 3600)
    }

    func hours(until other: Date) -> Int {
        Int((other.timeIntervalSince(self) / 3600).rounded())
    }
}
