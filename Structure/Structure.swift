//
//  Structure.swift
//  Structure
//
//  Created by Stephen Gerstacker on 12/20/15.
//  Copyright © 2016 Stephen H. Gerstacker. All rights reserved.
//

import Foundation
import SQLite

private let StructureQueueKey: UnsafeMutablePointer<Void> = UnsafeMutablePointer.alloc(1)

public class Structure {
    
    // MARK: - Properties
    
    var database: SQLiteDatabase = nil
    
    private var queue: dispatch_queue_t
    private var queueId: UnsafeMutablePointer<Void>
    
    internal var errorMessage: String {
        if let message = String.fromCString(sqlite3_errmsg(database)) {
            return message
        } else {
            return "<Unknown Error>"
        }
    }
    
    public var lastInsertedId: Int64 {
        return sqlite3_last_insert_rowid(database)
    }
    
    public internal(set) var userVersion: Int {
        get {
            do {
                let statement = try prepare("PRAGMA user_version")
                
                defer {
                    statement.finalize()
                }
                
                var version = -1
                try perform(statement) { row in
                    version = row[0]
                }
                
                return version
            } catch let e {
                fatalError("Failed to read user version: \(e)")
            }
        }
        
        set {
            do {
                try execute("PRAGMA user_version = \(newValue)")
            } catch let e {
                fatalError("Failed to write user version: \(e)")
            }
        }
    }
    
    
    // MARK: - Initialization
    
    convenience public init() throws {
        try self.init(path: ":memory:")
    }
    
    required public init(path: String) throws {
        // Build the execution queue
        queue = dispatch_queue_create("Structure Queue", DISPATCH_QUEUE_SERIAL)
        queueId = UnsafeMutablePointer.alloc(1)
        dispatch_queue_set_specific(queue, StructureQueueKey, queueId, nil)
        
        // Attempt to open the path
        let result = sqlite3_open_v2(path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        if result != SQLITE_OK {
            throw StructureError.fromSqliteResult(result)
        }
    }
    
    public func close() throws {
        var potentialError: StructureError? = nil
        
        dispatchWithinQueue {
            let result = sqlite3_close_v2(self.database)
            if result != SQLITE_OK {
                potentialError = StructureError.fromSqliteResult(result)
            } else {
                self.database = nil
            }
        }
        
        if let error = potentialError {
            throw error
        }
    }
    
    deinit {
        dispatch_queue_set_specific(queue, StructureQueueKey, nil, nil)
        queueId.dealloc(1)
        
        // Force a final closure, just in case
        if database != nil {
            sqlite3_close_v2(database)
        }
        
    }
    
    
    // MARK: - Statement Creation
    
    public func prepare(query: String) throws -> Statement {
        return try Statement(structure: self, query: query)
    }
    
    // MARK: - Thread Safety
    
    func dispatchWithinQueue(block: dispatch_block_t) {
        let currentId = dispatch_get_specific(StructureQueueKey)
        if currentId == queueId {
            block()
        } else {
            dispatch_sync(queue, block)
        }
    }
    
    // MARK: - Execution
    
    public func execute(query: String) throws {
        // Placeholder for an error that occurs in the block
        var potentialError: StructureError? = nil
        
        // Queue the execution
        dispatchWithinQueue {
            self.beginTransaction()
            
            // Attempt the execution
            var errorMessage: UnsafeMutablePointer<Int8> = nil
            let result = sqlite3_exec(self.database, query, nil, nil, &errorMessage)
            if result != SQLITE_OK {
                if let message = String.fromCString(errorMessage) {
                    potentialError = StructureError.InternalError(Int(result), message)
                } else {
                    potentialError = StructureError.InternalError(Int(result), "<Unknown exec error>")
                }
                
                sqlite3_free(errorMessage)
                
                self.rollbackTransaction()
            } else {
                self.commitTransaction()
            }

        };
        
        // If an error occurred in the block, throw it
        if let error = potentialError {
            throw error
        }
    }
    
    public func perform(statement: Statement) throws {
        try perform(statement, rowCallback: nil)
    }
    
    public func perform(statement: Statement, rowCallback: ((Row) -> ())?) throws {
        var potentialError: StructureError? = nil
        
        dispatchWithinQueue {
            // Step until there is an error or complete
            var keepGoing = true
            while keepGoing {
                let result = statement.step()
                
                switch result {
                case .Done:
                    keepGoing = false
                case .Error(let code):
                    potentialError = StructureError.fromSqliteResult(code)
                    keepGoing = false
                case .OK:
                    keepGoing = false
                case .Row:
                    if let callback = rowCallback {
                        callback(Row(statement: statement))
                    }
                case.Unhandled(let code):
                    fatalError("Unhandled result code from stepping a statement: \(code)")
                }
            }
        }
        
        if let error = potentialError {
            throw error
        }
    }
    
    public func transaction(block: () throws -> ()) throws {
        var potentialError: ErrorType? = nil
        
        dispatch_sync(queue) {
            // Mark the beginning of the transaction
            self.beginTransaction()
        
            do {
                try block()
                self.commitTransaction()
            } catch let e {
                potentialError = e
                self.rollbackTransaction()
            }
        }
        
        if let error = potentialError {
            throw error
        }
    }
    
    
    // MARK: - Transaction Management
    
    private func beginTransaction() {
        let result = sqlite3_exec(database, "BEGIN TRANSACTION", nil, nil, nil)
        if result != SQLITE_OK {
            fatalError("BEGIN TRANSACTION should never fail")
        }
    }
    
    private func commitTransaction() {
        let result = sqlite3_exec(database, "COMMIT TRANSACTION", nil, nil, nil)
        if result != SQLITE_OK {
            fatalError("COMMIT TRANSACTION should never fail")
        }
    }
    
    private func rollbackTransaction() {
        let result = sqlite3_exec(database, "ROLLBACK TRANSACTION", nil, nil, nil)
        if result != SQLITE_OK {
            fatalError("ROLLBACK TRANSACTION should never fail")
        }
    }
}
