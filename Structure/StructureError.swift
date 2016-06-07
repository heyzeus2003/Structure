//
//  StructureError.swift
//  Structure
//
//  Created by Stephen Gerstacker on 12/20/15.
//  Copyright © 2016 Stephen H. Gerstacker. All rights reserved.
//

import Foundation
import SQLite

/**
    Errors specific to the Structure framework.
 
    - Error: An error specific to how the Structure framework works.
    - InternalError: An error generated by the underlying SQLite API.
*/
public enum StructureError: ErrorType {
    case Error(String)
    case InternalError(Int, String)
    
    internal static func fromSqliteResult(result: Int32) -> StructureError {
        let errorMessage = sqlite3_errstr(result)
        if let error = String.fromCString(errorMessage) {
            return InternalError(Int(result), error)
        } else {
            return InternalError(0, "Unknown error")
        }
    }
}