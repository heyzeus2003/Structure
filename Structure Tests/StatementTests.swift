//
//  StatementTests.swift
//  Structure
//
//  Created by Stephen Gerstacker on 1/1/16.
//  Copyright © 2016 Stephen H. Gerstacker. All rights reserved.
//

import XCTest
@testable import Structure

class StatementTests: XCTestCase {

    // MARK: - Set Up & Tear Down
    
    var structure: Structure!
    
    override func setUp() {
        super.setUp()
        
        structure = try! Structure()
        try! structure.execute("CREATE TABLE foo (a INTEGER PRIMARY KEY AUTOINCREMENT, b TEXT, c REAL, d INT)")
    }
    
    override func tearDown() {
        try! structure.close()
        structure = nil
        
        super.tearDown()
    }
    
    
    // MARK: - Prepare Tests
    
    func testPrepareInvalidStatement() {
        do {
            try structure.prepare("SELECT FOO BAR BAZ")
            XCTFail("Preparation of invalid query succeeded")
        } catch let e {
            XCTSuccess("Preparation of invalid query failed: \(e)")
        }
    }
    
    func testPrepareRequiresNamedParameters() {
        do {
            try structure.prepare("SELECT a FROM foo WHERE b = ?")
            XCTFail("Preparation of query with unnamed parameters succeeded")
        } catch let e {
            XCTSuccess("Preparation of query with unnamed parameters failed: \(e)")
        }
        
    }
    
    func testPrepareValidStatement() {
        do {
            let statement = try structure.prepare("SELECT a, b, c FROM foo WHERE b IS :ONE OR b IS $TWO OR c IS @THREE")
            
            defer {
                statement.finalize()
            }
            
            XCTAssertEqual(3, statement.bindParameters.count)
            XCTAssertEqual(1, statement.bindParameters["ONE"])
            XCTAssertEqual(2, statement.bindParameters["TWO"])
            XCTAssertEqual(3, statement.bindParameters["THREE"])
            
            XCTAssertEqual(3, statement.columns.count)
            XCTAssertEqual(0, statement.columns["a"])
            XCTAssertEqual(1, statement.columns["b"])
            XCTAssertEqual(2, statement.columns["c"])
        } catch let e {
            XCTFail("Preparation of valid query failed: \(e)")
        }
    }
    
    // MARK: - Read / Write Tests
    
    func testDeleteStatement() {
        do {
            // Insert a row
            let insertStatement = try structure.prepare("INSERT INTO foo (b, c,d ) VALUES (:B, :C, :D)")
            
            defer {
                insertStatement.finalize()
            }
            
            insertStatement.bind("B", value: "foo")
            insertStatement.bind("C", value: 42.1)
            insertStatement.bind("D", value: 42)
            
            try structure.perform(insertStatement)
            
            // Ensure we have 1 row
            let initialCount = countFoo()
            XCTAssertEqual(1, initialCount)
            
            // Delete all rows
            let deleteStatement = try structure.prepare("DELETE FROM foo")
            
            defer {
                deleteStatement.finalize()
            }
            
            try structure.perform(deleteStatement)
            
            // Ensure we have 0 rows
            let deletedCount = countFoo()
            XCTAssertEqual(0, deletedCount)
        } catch let e {
            XCTFail("Failed testing delete statement: \(e)")
        }
    }
    
    func testInsertStatement() {
        do {
            // Ensure we have no rows
            let initialCount = countFoo()
            XCTAssertEqual(0, initialCount)
            
            // Insert a row
            let insertStatement = try structure.prepare("INSERT INTO foo (b, c, d) VALUES (:B, :C, :D)")
            
            defer {
                insertStatement.finalize()
            }
            
            insertStatement.bind("B", value: "foo")
            insertStatement.bind("C", value: 42.1)
            insertStatement.bind("D", value: 42)
            
            try structure.perform(insertStatement)
            
            // Ensure we have 1 row
            let updatedCount = countFoo()
            XCTAssertEqual(1, updatedCount)
            
            // Get the data that was inserted
            let lastId = structure.lastInsertedId
            let selectStatement = try structure.prepare("SELECT a, b, c, d FROM foo")
            
            defer {
                selectStatement.finalize()
            }
            
            try structure.perform(selectStatement) { row in
                let aString: Int64 = row["a"]
                let bString: String? = row["b"]
                let cString: Double = row["c"]
                let dString: Int = row["d"]
                
                XCTAssertEqual(lastId, aString)
                XCTAssertEqual("foo", bString)
                XCTAssertEqual(42.1, cString)
                XCTAssertEqual(42, dString)
                
                let aInt: Int64 = row[0]
                let bInt: String? = row[1]
                let cInt: Double = row[2]
                let dInt: Int = row[3]
                
                XCTAssertEqual(lastId, aInt)
                XCTAssertEqual("foo", bInt)
                XCTAssertEqual(42.1, cInt)
                XCTAssertEqual(42, dInt)
            }
        } catch let e {
            XCTFail("Failed testing insert statement: \(e)")
        }
    }
    
    func testUpdateStatement() {
        do {
            // Insert a row
            let insertStatement = try structure.prepare("INSERT INTO foo (b, c, d) VALUES (:B, :C, :D)")
            
            defer {
                insertStatement.finalize()
            }
            
            insertStatement.bind("B", value: "foo")
            insertStatement.bind("C", value: 42.1)
            insertStatement.bind("D", value: 42)
            
            try structure.perform(insertStatement)
        
            // Ensure we have 1 row
            let initialCount = countFoo()
            XCTAssertEqual(1, initialCount)
            
            // Get the data that was inserted
            let lastId = structure.lastInsertedId
            
            // Update the row
            let updateStatement = try structure.prepare("UPDATE foo SET b = :B, c = :C, d = :D where a = :A")
            
            defer {
                updateStatement.finalize()
            }
            
            updateStatement.bind("B", value: "bar")
            updateStatement.bind("C", value: 1.1)
            updateStatement.bind("D", value: 2)
            updateStatement.bind("A", value: lastId)
            
            try structure.perform(updateStatement)
            
            // Ensure there is still one row
            let updatedCount = countFoo()
            XCTAssertEqual(1, updatedCount)
            
            // Ensure the updated values are set
            let selectStatement = try structure.prepare("SELECT a, b, c, d FROM foo WHERE a = :A")
            
            defer {
                selectStatement.finalize()
            }
            
            selectStatement.bind("A", value: lastId)
            
            try structure.perform(selectStatement) { row in
                let aString: Int64 = row["a"]
                let bString: String? = row["b"]
                let cString: Double = row["c"]
                let dString: Int = row["d"]
                
                XCTAssertEqual(lastId, aString)
                XCTAssertEqual("bar", bString)
                XCTAssertEqual(1.1, cString)
                XCTAssertEqual(2, dString)
                
                let aInt: Int64 = row[0]
                let bInt: String? = row[1]
                let cInt: Double = row[2]
                let dInt: Int = row[3]
                
                XCTAssertEqual(lastId, aInt)
                XCTAssertEqual("bar", bInt)
                XCTAssertEqual(1.1, cInt)
                XCTAssertEqual(2, dInt)
            }
        } catch let e {
            XCTFail("Failed testing update statement: \(e)")
        }
    }
    
    // MARK: - Transaction Tests
    
    func testSuccessfulTransaction() {
        do {
            // Ensure there are no rows
            let initialCount = countFoo()
            XCTAssertEqual(0, initialCount)
            
            // Insert a series of data in a transaction
            try structure.transaction {
                let insertStatement = try self.structure.prepare("INSERT INTO foo (b, c) VALUES (:B, :C)")
                
                defer {
                    insertStatement.finalize()
                }
                
                insertStatement.bind("B", value: "foo")
                insertStatement.bind("C", value: 42.1)
                
                try self.structure.perform(insertStatement)
                
                insertStatement.reset()
                
                insertStatement.bind("B", value: "bar")
                insertStatement.bind("C", value: 1.1)
                
                try self.structure.perform(insertStatement)
            }
            
            // Ensure there are two rows
            let updatedCount = countFoo()
            XCTAssertEqual(2, updatedCount)
        } catch let e {
            XCTFail("Failed testing successful transaction: \(e)")
        }
    }
    
    func testFailedTransaction() {
        // Ensure there are no rows
        let initialCount = countFoo()
        XCTAssertEqual(0, initialCount)
        
        do {
            // Insert a some data, but fail
            try structure.transaction {
                let insertStatement = try self.structure.prepare("INSERT INTO foo (b, c) VALUES (:B, :C)")
                
                defer {
                    insertStatement.finalize()
                }
                
                insertStatement.bind("B", value: "foo")
                insertStatement.bind("C", value: 42.1)
                
                try self.structure.perform(insertStatement)
                
                insertStatement.reset()
                
                insertStatement.bind("B", value: "bar")
                insertStatement.bind("C", value: 1.1)
                
                try self.structure.perform(insertStatement)
                
                throw StructureError.Error("Forced Error")
            }
        } catch StructureError.Error(let e) {
            XCTAssertEqual("Forced Error", e)
        } catch let e {
            XCTFail("Unknown error when forcing a bad transaction: \(e)")
        }
        
        // Ensure there are still no rows
        let finalCount = countFoo()
        XCTAssertEqual(0, finalCount)
    }
    
    // MARK: - Utilities
    
    private func countFoo() -> Int {
        let statement = try! structure.prepare("SELECT COUNT(a) as count FROM foo")
        
        defer {
            statement.finalize()
        }
        
        var count = -1
        try! structure.perform(statement) { row in
            count = row["count"]
        }
        
        return count
    }
    
}
