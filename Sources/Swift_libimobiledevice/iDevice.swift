//
//  iDevice.swift
//  Swift_libimobiledevice
//
//  Created by Linus Henze on 2021-02-22.
//  Copyright © 2021 Pinauten GmbH. All rights reserved.
//

import Clibimobiledevice

public extension idevice_options {
    static func |(lhs: idevice_options, rhs: idevice_options) -> idevice_options {
        return Self(rawValue: lhs.rawValue | rhs.rawValue)
    }
}

public enum iDeviceError: Error {
    case invalidArg
    case unknownError
    case noDevice
    case notEnoughData
    case sslError
    case timeout
    case unknown(errorCode: Int32)
    
    static func error(forCode code: Int32) -> iDeviceError? {
        switch code {
        case 0:
            return nil
            
        case -1:
            return .invalidArg
        case -2:
            return .unknownError
        case -3:
            return .noDevice
        case -4:
            return .notEnoughData
        case -6:
            return .sslError
        case -7:
            return .timeout
            
        default:
            return .unknown(errorCode: code)
        }
    }
    
    static func throwOnErr(_ code: Int32) throws {
        if let err = error(forCode: code) {
            throw err
        }
    }
    
    static func throwOnErr(_ code: idevice_error_t) throws {
        try throwOnErr(code.rawValue)
    }
}

public class iDevice {
    public private(set) var handle: idevice_t!
    
    public static var allDeviceUDIDs: [String] {
        var devs: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>? = nil
        var count: Int32 = 0
        guard idevice_get_device_list(&devs, &count) == IDEVICE_E_SUCCESS else {
            return []
        }
        
        guard devs != nil else {
            return []
        }
        
        var res: [String] = []
        for i in 0..<Int(count) {
            guard let ptr = devs![i] else {
                continue
            }
            
            res.append(String(cString: ptr))
        }
        
        idevice_device_list_free(devs)
        
        return res
    }
    
    public static var allDeviceUDIDsExtended: [String: idevice_connection_type] {
        var devs: UnsafeMutablePointer<idevice_info_t?>? = nil
        var count: Int32 = 0
        guard idevice_get_device_list_extended(&devs, &count) == IDEVICE_E_SUCCESS else {
            return [:]
        }
        
        guard devs != nil else {
            return [:]
        }
        
        var res: [String: idevice_connection_type] = [:]
        for i in 0..<Int(count) {
            guard let ptr = devs![i] else {
                continue
            }
            
            res[String(cString: ptr.pointee.udid)] = ptr.pointee.conn_type
        }
        
        idevice_device_list_extended_free(devs)
        
        return res
    }
    
    public init(UDID: String) throws {
        var udid = UDID
        if udid == "first" {
            let all = Self.allDeviceUDIDs
            if all.count > 0 {
                udid = all[0]
            } else {
                throw iDeviceError.noDevice
            }
        }
        
        let options = IDEVICE_LOOKUP_USBMUX | IDEVICE_LOOKUP_NETWORK
        let res = idevice_new_with_options(&handle, udid, options)
        
        try iDeviceError.throwOnErr(res)
    }
    
    public func vendContainer(forApp app: String) throws -> AFC {
        return try HouseArrest(device: self).vendContainer(forApp: app)
    }
    
    public func vendDocuments(forApp app: String) throws -> AFC {
        return try HouseArrest(device: self).vendDocuments(forApp: app)
    }
    
    public func getProperties(ofDomain: String? = nil) throws -> [String: Any] {
        var client: lockdownd_client_t?
        let err = lockdownd_client_new_with_handshake(handle, &client, nil)
        try iDeviceError.throwOnErr(err.rawValue)
        
        defer { lockdownd_client_free(client) }
        
        let outPlist = LibiMobileDevicePlist()
        let err2 = lockdownd_get_value(client, ofDomain, nil, &outPlist.handle)
        try iDeviceError.throwOnErr(err2.rawValue)
        
        return try outPlist.toSwift() as! [String: Any]
    }
    
    deinit {
        if handle != nil {
            idevice_free(handle)
            handle = nil
        }
    }
}
