//
//  HelperToolLaunchdPropertyList.swift
//  SwiftAuthorizationSample
//
//  Created by Josh Kaplan on 2021-10-23
//

import Foundation
import EmbeddedPropertyList

/// Read only representation of the helper tool's embedded launchd property list.
struct HelperToolLaunchdPropertyList: Decodable {
    /// Value for `MachServices`.
    let machServices: [String : Bool]
    /// Value for `Label`.
    let label: String
    
    // Used by the decoder to map the names of the entries in the property list to the property names of this struct
    private enum CodingKeys: String, CodingKey {
        case machServices = "MachServices"
        case label = "Label"
    }
    
    /// Creates an immutable in memory representation of the property list by attempting to read it from the helper tool.
    ///
    /// - Returns: An immutable representation of the property list.
    static func main() throws -> HelperToolLaunchdPropertyList {
        let propertyListData = try EmbeddedPropertyListReader.launchd.readInternal()
        return try PropertyListDecoder().decode(HelperToolLaunchdPropertyList.self, from: propertyListData)
    }
    
    /// Creates an immutable in memory representation of the property list by attempting to read it from the helper tool.
    ///
    /// - Parameters:
    ///   - from: Location of the helper tool on disk.
    init(from url: URL) throws {
        let propertyListData = try EmbeddedPropertyListReader.launchd.readExternal(from: url)
        self = try PropertyListDecoder().decode(HelperToolLaunchdPropertyList.self, from: propertyListData)
    }
}
