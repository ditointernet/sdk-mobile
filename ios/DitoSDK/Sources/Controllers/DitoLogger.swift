import Foundation

/**
 DitoLogger is a enum that contains the log level cases to print messages

 Example for fatal log:

     DitoLogger.fatal("Can't init the db")
 */

enum DitoLogger: String {
  case fatal = "FATAL"
  case error = "ERROR"
  case warning = "WARNING"
  case information = "INFORMATION"
  case debug = "DEBUG"
  case trace = "TRACE"
}

extension DitoLogger {
  private static let dateFormat = "yyyy-MM-dd hh:mm:ssSSS"

  /**
   Private log method that will print message using other variables to indicate the timestamp, file name, line, column and the function that cause the message
  
   - Parameters:
      - items: The sequence of objects to be printed
      - separator: Used to concatenate the string objects **items**
      - filename: The path to the file that called the log event
      - line: Indicates which line of the file the event occurred
      - column: It is combined with the line of the file to exactly find the error
      - function: The name of the function that called the log event
   */
  func callAsFunction(
    _ items: Any...,
    separator: String = " ",
    filename: String = #file,
    line: Int = #line,
    column: Int = #column,
    function: String = #function
  ) {

    let message = items.map { "\($0)" }.joined(separator: separator)
    let dateString = DitoLogger.dateFormatter.string(from: Date())
    let logAtPath =
      "\(DitoLogger.sourceFileName(filePath: filename))[\(line):\(column)]"
    let functionError = "at \(function) => \(message)"

    print("\(dateString) \(self.rawValue) \(logAtPath) \(functionError)")
  }

  static var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = dateFormat
    formatter.locale = Locale.current
    formatter.timeZone = TimeZone.current
    return formatter
  }

  /// Private method to get the name of the file only
  static func sourceFileName(filePath: String) -> String {
    filePath.components(separatedBy: "/").last ?? ""
  }
}

/// Overrides Swift.print(_:, separator:, terminator:) function to only print when app is in DEBUG environment
func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
  if ProcessInfo.processInfo.arguments.contains("EnabledDebug") {
    Swift.print(
      items.map { "\($0)" }.joined(separator: separator),
      terminator: terminator
    )
  }
}
