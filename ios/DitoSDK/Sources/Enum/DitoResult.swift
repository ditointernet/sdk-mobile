//
//  Result.swift
//  DitoSDK
//
//  Created by Rodrigo Damacena Gamarra Maciel on 22/12/20.
//


import Foundation

typealias NetworkCompletion<T: Decodable> = (_ result: DitoResult<T>)-> Void

enum DitoResult<T> {
    case success(data: T)
    case failure(error: DitoErrorType)
}
 
