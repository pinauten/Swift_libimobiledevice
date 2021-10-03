//
//  PropertyListService.swift
//  Swift_libimobiledevice
//
//  Created by Linus Henze on 2021-09-07.
//  Copyright © 2021 Pinauten GmbH. All rights reserved.
//

import Foundation
import Clibimobiledevice

public enum PropertyListServiceError: Error {
    case invalidArg
    case plistError
    case muxError
    case sslError
    case receiveTimeout
    case notEnoughData
    case unknownError
    case unknown(errorCode: Int32)
    
    public static func error(forCode code: Int32) -> PropertyListServiceError? {
        switch code {
        case PROPERTY_LIST_SERVICE_E_SUCCESS.rawValue:
            return nil
            
        case PROPERTY_LIST_SERVICE_E_INVALID_ARG.rawValue:
            return .invalidArg
        case PROPERTY_LIST_SERVICE_E_PLIST_ERROR.rawValue:
            return .plistError
        case PROPERTY_LIST_SERVICE_E_MUX_ERROR.rawValue:
            return .muxError
        case PROPERTY_LIST_SERVICE_E_SSL_ERROR.rawValue:
            return .sslError
        case PROPERTY_LIST_SERVICE_E_RECEIVE_TIMEOUT.rawValue:
            return .receiveTimeout
        case PROPERTY_LIST_SERVICE_E_NOT_ENOUGH_DATA.rawValue:
            return .notEnoughData
        case PROPERTY_LIST_SERVICE_E_UNKNOWN_ERROR.rawValue:
            return .unknownError
            
        default:
            return .unknown(errorCode: code)
        }
    }
    
    public static func throwOnErr(_ code: Int32) throws {
        if let err = error(forCode: code) {
            throw err
        }
    }
    
    public static func throwOnErr(_ code: property_list_service_error_t) throws {
        try throwOnErr(code.rawValue)
    }
}

public class PropertyListService {
    public private(set) var handle: property_list_service_client_t!
    
    // Handles we need to keep alive
    public private(set) var device: iDevice
    
    public init(device: iDevice, serviceName: String) throws {
        var err = PROPERTY_LIST_SERVICE_E_SUCCESS.rawValue
        _ = withUnsafePointer(to: &handle) {
            service_client_factory_start_service(device.handle, serviceName, UnsafeMutablePointer<UnsafeMutableRawPointer?>(OpaquePointer($0)), nil, { device, service, handlePtr in
                let ptr = UnsafeMutablePointer<property_list_service_client_t?>(OpaquePointer(handlePtr))
                
                return property_list_service_client_new(device, service, ptr).rawValue
            }, &err)
        }
        
        try PropertyListServiceError.throwOnErr(err)
        
        self.device = device
    }
    
    public func send(plist: Any) throws {
        let p = try LibiMobileDevicePlist(fromObject: plist)
        let err = property_list_service_send_xml_plist(handle, p.handle)
        
        try PropertyListServiceError.throwOnErr(err)
    }
    
    public func receive() throws -> Any {
        let plist = LibiMobileDevicePlist()
        let err = property_list_service_receive_plist(handle, &plist.handle)
        
        try PropertyListServiceError.throwOnErr(err)
        
        return try plist.toSwift()
    }
    
    public func sendWithReply(plist: Any) throws -> Any {
        try send(plist: plist)
        return try receive()
    }
    
    deinit {
        property_list_service_client_free(handle)
    }
}
