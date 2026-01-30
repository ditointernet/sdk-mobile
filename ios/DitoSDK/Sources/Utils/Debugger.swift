import Foundation

enum DebugStates {
  case none
  case path
  case verbose
}

let debugState: DebugStates = {
  guard
    let path = Bundle.main.path(
      forResource: "GlobalState",
      ofType: "plist"
    ),
    let dictionary = NSDictionary(contentsOfFile: path),
    let pathEnabled = dictionary["PathDebug"] as? Bool,
    let verboseEnabled = dictionary["VerboseDebug"] as? Bool
  else {
    return .none
  }

  if verboseEnabled { return .verbose } else if pathEnabled { return .path }
  return .none
}()

//Debugger.debug("Função XPTO", type: .path)
//Debugger.debug("valor da variável X = \(variavel)")

struct Debugger {

  func debug(_ info: String, type: DebugStates = .verbose) {

    switch debugState {
    case .verbose:
      DitoLogger.debug(info)
    case .path:
      if type == .path { DitoLogger.debug(info) }
    case .none:
      return
    }
  }
}
