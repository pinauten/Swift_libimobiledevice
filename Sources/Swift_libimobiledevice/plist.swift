//
//  plist.swift
//  Swift_libimobiledevice
//
//  Created by Linus Henze on 2021-02-22.
//  Copyright © 2021 Pinauten GmbH. All rights reserved.
//

import Foundation
import Clibimobiledevice

internal class LibiMobileDevicePlist {
    public var handle: plist_t!
    
    init() {
        
    }
    
    init(fromObject obj: Any) throws {
        let res = try PropertyListSerialization.data(fromPropertyList: obj, format: .xml, options: .zero)
        
        res.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            plist_from_xml(ptr.baseAddress!.assumingMemoryBound(to: CChar.self), UInt32(ptr.count), &handle)
        }
    }
    
    init(consumingPlist plist: plist_t!) throws {
        handle = plist
    }
    
    func toSwift() throws -> Any {
        assert(handle != nil)
        
        var strPtr: UnsafeMutablePointer<CChar>?
        var len: UInt32 = 0
        
        plist_to_xml(handle, &strPtr, &len)
        defer {
            // Free the XML again
            plist_to_xml_free(strPtr)
        }
        
        let res = try PropertyListSerialization.propertyList(from: Data(bytes: strPtr!, count: Int(len)), format: nil)
        
        return res
    }
    
    deinit {
        if handle != nil {
            plist_free(handle)
        }
    }
}
