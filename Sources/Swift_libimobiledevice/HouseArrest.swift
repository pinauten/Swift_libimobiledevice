//
//  HouseArrest.swift
//  Swift_libimobiledevice
//
//  Created by Linus Henze on 2021-02-22.
//  Copyright © 2021 Pinauten GmbH. All rights reserved.
//

import Foundation
import Clibimobiledevice

public enum HouseArrestError: Error {
    case invalidArg
    case plistError
    case connectionFailed
    case invalidMode
    case unknownError
    case otherError(description: String)
    case unknown(errorCode: Int32)
    
    static func error(forCode code: Int32) -> HouseArrestError? {
        switch code {
        case 0:
            return nil
            
        case -1:
            return .invalidArg
        case -2:
            return .plistError
        case -3:
            return .connectionFailed
        case -4:
            return .invalidMode
        case -256:
            return .unknownError
            
        default:
            return .unknown(errorCode: code)
        }
    }
    
    static func throwOnErr(_ code: Int32) throws {
        if let err = error(forCode: code) {
            throw err
        }
    }
    
    static func throwOnErr(_ code: house_arrest_error_t) throws {
        try throwOnErr(code.rawValue)
    }
}

public class HouseArrest {
    public private(set) var handle: house_arrest_client_t!
    
    // Handles we need to keep alive
    public private(set) var device: iDevice
    
    public init(device: iDevice) throws {
        let err = house_arrest_client_start_service(device.handle, &handle, nil)
        
        try HouseArrestError.throwOnErr(err)
        
        self.device = device
    }
    
    private func vendCommon() throws -> AFC {
        let plist = LibiMobileDevicePlist()
        let err = house_arrest_get_result(handle, &plist.handle)
        try HouseArrestError.throwOnErr(err)
        
        guard let dict = try plist.toSwift() as? [String: Any] else {
            throw HouseArrestError.plistError
        }
        
        guard let status = dict["Status"] as? String else {
            if let err = dict["Error"] as? String {
                throw HouseArrestError.otherError(description: err)
            }
            
            throw HouseArrestError.plistError
        }
        
        guard status == "Complete" else {
            throw HouseArrestError.plistError
        }
        
        return try AFC(houseArrest: self)
    }
    
    public func vendContainer(forApp app: String) throws -> AFC {
        let err = house_arrest_send_command(handle, "VendContainer", app)
        try HouseArrestError.throwOnErr(err)
        
        return try vendCommon()
    }
    
    public func vendDocuments(forApp app: String) throws -> AFC {
        let err = house_arrest_send_command(handle, "VendDocuments", app)
        try HouseArrestError.throwOnErr(err)
        
        return try vendCommon()
    }
    
    deinit {
        if handle != nil {
            house_arrest_client_free(handle)
            handle = nil
        }
    }
}
