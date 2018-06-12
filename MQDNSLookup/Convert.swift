//
//  Convert.swift
//  privoxy-swift
//
//  Created by AQY on 2018/6/12.
//  Copyright © 2018年 AQY. All rights reserved.
//

import Foundation

extension UInt16 {
    var bytes: [UInt8] {
        return [UInt8(truncatingIfNeeded: self >> 8), UInt8(truncatingIfNeeded:self)]
    }
}

extension UInt32 {
    var bytes: [UInt8] {
        return [UInt8(truncatingIfNeeded: self >> 24), UInt8(truncatingIfNeeded:self >> 16), UInt8(truncatingIfNeeded:self >> 8), UInt8(truncatingIfNeeded:self)]
    }
}

extension Array where Element == UInt8 {
    var toUInt16 : UInt16 {
        guard self.count >= 2 else {
            return 0
        }
        return UInt16(self[0]) << 8 | UInt16(self[1])
    }
    
    var toUInt32 : UInt16 {
        guard self.count >= 4 else {
            return 0
        }
        return UInt16(self[0]) << 24 | UInt16(self[1]) << 16 | UInt16(self[2]) << 8 | UInt16(self[3])
    }
}

extension String {
    var hexBytes: Array<UInt8> {
        
        var bytes = [UInt8]()
        for i in 0 ..< self.count / 2 {
            
            var p: UInt32 = 0
            Scanner(string: String(self[String.Index.init(encodedOffset: i * 2) ..< String.Index.init(encodedOffset: i * 2 + 2)])).scanHexInt32(&p)
            bytes.append(UInt8(truncatingIfNeeded: p))
        }
        return bytes
    }
    
    var uuidData: Data? {
        if let obj = UUID.init(uuidString: self) {
            var uuid = obj.uuid
            let uuidBytes = [UInt8](UnsafeBufferPointer.init(start: &uuid.0, count: MemoryLayout.size(ofValue: uuid)))
            let uuiddata = Data.init(bytes: uuidBytes)
            return uuiddata
        }
        return nil
    }
}

extension Data {
    var cstr: String {
        
        var rawStr = ""
        for byte in self.enumerated() {
            rawStr.append(Character.init(Unicode.Scalar.init(byte.element)))
        }
        return rawStr
    }
}
