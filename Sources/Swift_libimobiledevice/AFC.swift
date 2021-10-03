//
//  AFC.swift
//  Swift_libimobiledevice
//
//  Created by Linus Henze on 2021-02-22.
//  Copyright © 2021 Pinauten GmbH. All rights reserved.
//

import Foundation
import Clibimobiledevice

public enum AFCError: Error {
    case unknownError
    case opHeaderInvalid
    case noResources
    case readError
    case writeError
    case unknownPacketType
    case invalidArg
    case objectNotFound
    case objectIsDir
    case permDenied
    case serviceNotConnected
    case opTimeout
    case tooMuchData
    case endOfData
    case opNotSupported
    case objectExists
    case objectBusy
    case noSpaceLeft
    case opWouldBlock
    case ioError
    case opInterrupted
    case opInProgress
    case internalError
    case muxError
    case noMem
    case notEnoughData
    case dirNotEmpty
    case forceSignedType
    case unknown(errorCode: Int32)
    
    static func error(forCode code: Int32) -> AFCError? {
        switch code {
        case 0:
            return nil
            
        case 1:
            return .unknownError
        case 2:
            return .opHeaderInvalid
        case 3:
            return .noResources
        case 4:
            return .readError
        case 5:
            return .writeError
        case 6:
            return .unknownPacketType
        case 7:
            return .invalidArg
        case 8:
            return .objectNotFound
        case 9:
            return .objectIsDir
        case 10:
            return .permDenied
        case 11:
            return .serviceNotConnected
        case 12:
            return .opTimeout
        case 13:
            return .tooMuchData
        case 14:
            return .endOfData
        case 15:
            return .opNotSupported
        case 16:
            return .objectExists
        case 17:
            return .objectBusy
        case 18:
            return .noSpaceLeft
        case 19:
            return .opWouldBlock
        case 20:
            return .ioError
        case 21:
            return .opInterrupted
        case 22:
            return .opInProgress
        case 23:
            return .internalError
        case 30:
            return .muxError
        case 31:
            return .noMem
        case 32:
            return .notEnoughData
        case 33:
            return .dirNotEmpty
        case -1:
            return .forceSignedType
            
        default:
            return .unknown(errorCode: code)
        }
    }
    
    static func throwOnErr(_ code: Int32) throws {
        if let err = error(forCode: code) {
            throw err
        }
    }
    
    static func throwOnErr(_ code: afc_error_t) throws {
        try throwOnErr(code.rawValue)
    }
}

public class AFC {
    public private(set) var handle: afc_client_t!
    
    // Handles we need to keep alive
    public private(set) var device: iDevice
    private var haClient: HouseArrest?
    
    public init(device: iDevice) throws {
        let err = afc_client_start_service(device.handle, &handle, nil)
        
        try AFCError.throwOnErr(err)
        
        self.device = device
    }
    
    internal init(houseArrest: HouseArrest) throws {
        self.haClient = houseArrest
        self.device = houseArrest.device
        
        let err = afc_client_new_from_house_arrest_client(houseArrest.handle, &self.handle)
        try AFCError.throwOnErr(err)
    }
    
    public func listDir(atPath path: String) throws -> [String] {
        var contents: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
        let err = afc_read_directory(handle, path, &contents)
        try AFCError.throwOnErr(err)
        
        if contents == nil {
            return []
        }
        
        var result: [String] = []
        var i = 0
        while contents![i] != nil && contents![i]![0] != 0 {
            result.append(String(cString: contents![i]!))
            i += 1
        }
        
        afc_dictionary_free(contents)
        
        return result
    }
    
    public func getInfo(forFile file: String) throws -> [String] {
        var fileInfo: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
        let err = afc_get_file_info(handle, file, &fileInfo)
        try AFCError.throwOnErr(err)
        
        if fileInfo == nil {
            return []
        }
        
        var result: [String] = []
        var i = 0
        while fileInfo![i] != nil && fileInfo![i]![0] != 0 {
            result.append(String(cString: fileInfo![i]!))
            i += 1
        }
        
        afc_dictionary_free(fileInfo)
        
        return result
    }
    
    deinit {
        if handle != nil {
            afc_client_free(handle)
            handle = nil
        }
    }
}
