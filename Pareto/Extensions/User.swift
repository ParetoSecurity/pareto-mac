//
//  User.swift
//  Pareto Security
//
//  Created by Janez Troha on 25/08/2022.
//
// https://stackoverflow.com/a/64034073

import Cocoa
import CoreServices
import Foundation

enum QueryError: Swift.Error {
    case queryExecutionFailed
    case queriedWithoutResult
}

struct User {
    static let current = User()

    private func getUser() throws -> CSIdentity {
        let query = CSIdentityQueryCreateForCurrentUser(kCFAllocatorDefault).takeRetainedValue()
        let flags = CSIdentityQueryFlags()
        guard CSIdentityQueryExecute(query, flags, nil) else { throw QueryError.queryExecutionFailed }

        let users = CSIdentityQueryCopyResults(query).takeRetainedValue() as! [CSIdentity]

        guard let currentUser = users.first else { throw QueryError.queriedWithoutResult }

        return currentUser
    }

    private func getAdminGroup() throws -> CSIdentity {
        let privilegeGroup = "admin" as CFString
        let authority = CSGetDefaultIdentityAuthority().takeRetainedValue()
        let query = CSIdentityQueryCreateForName(kCFAllocatorDefault,
                                                 privilegeGroup,
                                                 kCSIdentityQueryStringEquals,
                                                 kCSIdentityClassGroup,
                                                 authority).takeRetainedValue()
        let flags = CSIdentityQueryFlags()

        guard CSIdentityQueryExecute(query, flags, nil) else { throw QueryError.queryExecutionFailed }
        let groups = CSIdentityQueryCopyResults(query).takeRetainedValue() as! [CSIdentity]

        guard let adminGroup = groups.first else { throw QueryError.queriedWithoutResult }

        return adminGroup
    }

    var isAdmin: Bool {
        do {
            let user = try getUser()
            let group = try getAdminGroup()
            return CSIdentityIsMemberOfGroup(user, group)
        } catch {
            return false
        }
    }
}
