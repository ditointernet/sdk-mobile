//
//  DTErrorType.swift
//  DitoSDK
//
//  Created by Rodrigo Damacena Gamarra Maciel on 22/12/20.
//

import Foundation


enum DitoErrorType: Error, LocalizedError {
    case parseUrlFail
    case serverError
    case noConnectivity
    case invalidJSON
    case unknown
    case objectError
    case defaultError(Error)
    
    var errorDescription: String? {
        switch self {
        case .parseUrlFail:
            return "The URL cannot be initialized."
        case .serverError:
            return "There was an error communicating with the server.\nTry again."
        case .noConnectivity:
            return "Check your internet connection"
        case .invalidJSON:
            return "Invalid JSON"
        case .unknown:
            return "Unkown error"
        case .objectError:
            return "Error fetching object"
        case .defaultError(let error):
            return error.localizedDescription
        }
    }
}
