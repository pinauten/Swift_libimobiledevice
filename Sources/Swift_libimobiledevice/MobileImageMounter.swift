//
//  MobileImageMounter.swift
//  Swift_libimobiledevice
//
//  Created by Linus Henze on 2021-09-07.
//  Copyright © 2021 Pinauten GmbH. All rights reserved.
//

import Foundation
import Clibimobiledevice

public enum MobileImageMounterError: Error {
    case failedToGetImages
    case failedToUploadImage
    case failedToMountImage(additionalData: [String: Any]? = nil)
    case failedToUnmountImage
    case cryptexNotFound
    case failedToGetCryptexNonce
}

public class MobileImageMounter {
    public let service: PropertyListService
    
    public init(device: iDevice) throws {
        service = try PropertyListService(device: device, serviceName: "com.apple.mobile.mobile_image_mounter")
    }
    
    public func getMountedImages() throws -> [[String: Any]] {
        guard let res = try service.sendWithReply(plist: [
            "Command": "CopyDevices"
        ]) as? [String: Any] else {
            throw MobileImageMounterError.failedToGetImages
        }
        
        guard res["Status"] as? String == "Complete" else {
            throw MobileImageMounterError.failedToGetImages
        }
        
        guard let list = res["EntryList"] as? [[String: Any]] else {
            throw MobileImageMounterError.failedToGetImages
        }
        
        return list
    }
    
    internal func uploadCryptex(signature: Data, cryptex: Data) throws {
        guard let res = try service.sendWithReply(plist: [
            "Command": "ReceiveBytes",
            "ImageSignature": signature,
            "ImageSize": UInt(cryptex.count),
            "ImageType": "Cryptex"
        ]) as? [String: Any] else {
            throw MobileImageMounterError.failedToUploadImage
        }
        
        guard res["Status"] as? String == "ReceiveBytesAck" else {
            throw MobileImageMounterError.failedToUploadImage
        }
        
        guard let sv = withUnsafePointer(to: service.handle, { ptr in
            UnsafePointer<UnsafePointer<service_client_t?>?>(OpaquePointer(ptr)).pointee?.pointee
        }) else {
            throw MobileImageMounterError.failedToUploadImage
        }
        
        var idx = 0
        while idx < cryptex.count {
            var amount = 65536
            if amount > (cryptex.count - idx) {
                amount = cryptex.count - idx
            }
            
            var sent: UInt32 = 0
            guard cryptex.withUnsafeBytes({ (ptr: UnsafeRawBufferPointer) in
                service_send(sv, ptr.baseAddress!.advanced(by: idx).assumingMemoryBound(to: CChar.self), UInt32(amount), &sent)
            }) == SERVICE_E_SUCCESS else {
                throw MobileImageMounterError.failedToUploadImage
            }
            
            idx += amount
        }
        
        guard let res = try service.receive() as? [String: Any] else {
            throw MobileImageMounterError.failedToUploadImage
        }
        
        guard res["Status"] as? String == "Complete" else {
            throw MobileImageMounterError.failedToGetImages
        }
    }
    
    public func installCryptex(trustCache: Data, infoPlist: Data, signature: Data, cryptex: Data) throws -> [String: Any] {
        try uploadCryptex(signature: signature, cryptex: cryptex)
        
        guard let res = try service.sendWithReply(plist: [
            "Command": "MountImage",
            "ImageTrustCache": trustCache,
            "ImageInfoPlist": infoPlist,
            "ImageSignature": signature,
            "ImageType": "Cryptex"
        ]) as? [String: Any] else {
            throw MobileImageMounterError.failedToMountImage()
        }
        
        guard res["Status"] as? String == "Complete" else {
            throw MobileImageMounterError.failedToMountImage(additionalData: res)
        }
        
        return res
    }
    
    public func installCryptex(trustCachePath: String, infoPlistPath: String, signaturePath: String, cryptexPath: String) throws -> [String: Any] {
        let trustCache = try Data(contentsOf: URL(fileURLWithPath: trustCachePath))
        let infoPlist  = try Data(contentsOf: URL(fileURLWithPath: infoPlistPath))
        let signature  = try Data(contentsOf: URL(fileURLWithPath: signaturePath))
        let cryptex    = try Data(contentsOf: URL(fileURLWithPath: cryptexPath))
        
        return try installCryptex(trustCache: trustCache, infoPlist: infoPlist, signature: signature, cryptex: cryptex)
    }
    
    public func uninstallCryptex(atPath path: String) throws {
        guard let res = try service.sendWithReply(plist: [
            "Command": "UnmountImage",
            "MountPath": path
        ]) as? [String: Any] else {
            throw MobileImageMounterError.failedToUnmountImage
        }
        
        guard res["Status"] as? String == "Complete" else {
            throw MobileImageMounterError.failedToUnmountImage
        }
    }
    
    public func uninstallCryptex(withIdentifier identifier: String) throws {
        for image in try getMountedImages() {
            if let id = image["CryptexName"] as? String,
               id == identifier {
                if let path = image["MountPath"] as? String {
                    try uninstallCryptex(atPath: path)
                    return
                }
            }
        }
        
        throw MobileImageMounterError.cryptexNotFound
    }
    
    public func getCryptexNonce() throws -> Data {
        guard let res = try service.sendWithReply(plist: [
            "Command": "QueryCryptexNonce"
        ]) as? [String: Any] else {
            throw MobileImageMounterError.failedToGetCryptexNonce
        }
        
        guard let nonce = res["CryptexNonce"] as? Data else {
            throw MobileImageMounterError.failedToGetCryptexNonce
        }
        
        return nonce
    }
    
    deinit {
        _ = try? service.sendWithReply(plist: ["Command": "Hangup"])
    }
}
