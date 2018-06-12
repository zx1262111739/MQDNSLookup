//
//  MQDNSLookup.swift
//  MQHTTPRequest
//
//  Created by AQY on 2018/6/12.
//  Copyright © 2018年 AQY. All rights reserved.
//

import Cocoa
import CocoaAsyncSocket

class MQDNSMessage : NSObject {
    
    var id: UInt16 = 0
    var flags: UInt16 = 1 << 8
    var qdCount: UInt16 = 1
    var anCount: UInt16 = 0
    var nsCount: UInt16 = 0
    var arCount: UInt16 = 0
    
    // queries
    var qName: String = ""
    var qType: UInt16 = 1
    var qClass: UInt16 = 1
    
    // answers
    struct Answer {
        var name: String = ""
        var type: UInt16 = 0
        var `class`: UInt16 = 0
        var ttl: UInt32 = 0
        /** 地址或者别名 */
        var data: String = ""
    }
    var answers: [Answer]?
    
    override init() {
        super.init()
    }
    init(data: Data) {
        super.init()
        
        id = [UInt8](data[0 ..< 2]).toUInt16
        flags = [UInt8](data[2 ..< 4]).toUInt16
        qdCount = [UInt8](data[4 ..< 6]).toUInt16
        anCount = [UInt8](data[6 ..< 8]).toUInt16
        nsCount = [UInt8](data[8 ..< 10]).toUInt16
        arCount = [UInt8](data[10 ..< 12]).toUInt16
        
        // queries data
        var idx = 12
        
        /// 提取name
        ///
        /// - Parameter offset:
        /// - Returns:
        func fetchName(offset: Int) -> (String, Int) {
            
            var i = offset
            var str = ""
            while i < data.count {
                let len = Int(data[i])
                if len == 0 {
                    i += 1
                    str.removeLast()
                    break
                }
                
                if len & 0xC0 == 0xC0 {
                    
                    let offset = ([UInt8](data[i ..< i + 2]).toUInt16) ^ 0xC000
                    let t = fetchName(offset: Int(offset))
                    str.append(t.0)
                    i = i + 2
                    break
                }
                
                
                i += 1
                for j in i ..< i + len {
                    str.append(Character.init(Unicode.Scalar.init(data[j])))
                }
                str.append(".")
                i += len
            }
            return (str, i)
        }
        
        let t = fetchName(offset: idx)
        qName = t.0
        idx = t.1
        
        qType = [UInt8](data[idx ..< idx + 2]).toUInt16
        idx += 2
        
        qClass = [UInt8](data[idx ..< idx + 2]).toUInt16
        idx += 2
        
        // answers data
        answers = [Answer]()
        while idx < data.count {
            
            var ar = Answer()
            let ident = [UInt8](data[idx ..< idx + 2]).toUInt16
            if ident & 0xC000 != 0xC000 {
                if ident == 0x0000 {
                    break
                }
                
                // 元信息标示
                let t = fetchName(offset: idx)
                ar.name = t.0
                idx = t.1
            } else {
                // 偏移指针
                let offset = ident ^ 0xC000
                let t = fetchName(offset: Int(offset))
                ar.name = t.0
                idx += 2
            }
            
            ar.type = [UInt8](data[idx ..< idx + 2]).toUInt16
            idx += 2
            
            ar.class = [UInt8](data[idx ..< idx + 2]).toUInt16
            idx += 2
            
            ar.class = [UInt8](data[idx ..< idx + 4]).toUInt32
            idx += 4
            
            let dataLen = Int([UInt8](data[idx ..< idx + 2]).toUInt16)
            idx += 2
            
            /// 别名
            switch ar.type {
            case 0x01:
                let ipData = [UInt8](data[idx ..< idx + dataLen])
                ar.data = "\(ipData[0]).\(ipData[1]).\(ipData[2]).\(ipData[3])"
            case 0x05:
                let t = fetchName(offset: idx)
                ar.data = t.0
            default:
                break
            }
            answers?.append(ar)
            idx += dataLen
        }
    }
    
    func encode() -> Data? {
        
        let components = qName.components(separatedBy: ".")
        guard components.count >= 2 else {
            return nil
        }
        var data = Data()
        data.append(contentsOf: id.bytes)
        data.append(contentsOf: flags.bytes)
        data.append(contentsOf: qdCount.bytes)
        data.append(contentsOf: anCount.bytes)
        data.append(contentsOf: nsCount.bytes)
        data.append(contentsOf: arCount.bytes)
        
        var nameData = Data()
        for c in components {
            if let d = c.data(using: .utf8) {
                let len = UInt8(truncatingIfNeeded: d.count)
                nameData.append(len)
                nameData.append(d)
            }
        }
        nameData.append(0)
        data.append(nameData)
        data.append(contentsOf: qType.bytes)
        data.append(contentsOf: qClass.bytes)
        
        if data.count > 512 {
            flags = flags | 1 << 9
            data.replaceSubrange(Range<Data.Index>.init(uncheckedBounds: (lower: 2, upper: 4)), with: &flags, count: 2)
        }
        
        return data
    }
}

class MQDNSCache : NSObject {
    var server: String = ""
    var resultDict = [String : MQDNSMessage]()
}


fileprivate let IPv4Regular = "((25[0-5]|2[0-4]\\d|[01]?\\d\\d?)\\.){3}(25[0-5]|2[0-4]\\d|[01]?\\d\\d?)"
fileprivate let IPv6Regular = "\\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}))|:)))(%.+)?\\s*"

class MQDNSLookup: NSObject, GCDAsyncUdpSocketDelegate {
    
    static var `default` = MQDNSLookup()
    
    typealias MQDNSLookupCompletion = (String?, Error?)->Void
    
    private var completions = [Int : MQDNSLookupCompletion]()
    private var lookupCount: UInt16 = 0
    private var udpSocket: GCDAsyncUdpSocket?
    private var cacheDict = [String : MQDNSCache]()
    
    private var ipv4Predicate = NSPredicate.init(format: "SELF MATCHES %@", IPv4Regular)
    private var ipv6Predicate = NSPredicate.init(format: "SELF MATCHES %@", IPv6Regular)
    
    override init() {
        super.init()
        
        let queue = DispatchQueue.init(label: "MQDNSLookup")
        udpSocket = GCDAsyncUdpSocket.init(delegate: self, delegateQueue: queue)
        do {
            try udpSocket?.bind(toPort: 0)
            try udpSocket?.beginReceiving()
        } catch {
            print(error)
        }
    }
    
    /// DNS查询
    ///
    /// - Parameters:
    ///   - name: 域名
    ///   - server: DNS服务器 // 101.132.183.99
    ///   - completion: 返回block ip只返回第一个 也可能一个都没
    func lookup(_ name: String, server: String = "114.114.114.114", completion: @escaping MQDNSLookupCompletion) {
        
        if ipv4Predicate.evaluate(with: name) {
            completion(name, nil)
            return
        }
        
        if ipv6Predicate.evaluate(with: name) {
            completion(name, nil)
            return
        }
        
        if let cache = cacheDict[server], let mess = cache.resultDict[name] {
            response(mess, completion)
            return
        }
        
        let mess = MQDNSMessage()
        mess.id = lookupCount
        mess.qName = name
        if let data = mess.encode() {
            udpSocket?.send(data, toHost: server, port: 53, withTimeout: 30, tag: Int(lookupCount))
        }
        
        completions[Int(mess.id)] = completion
        
        lookupCount = lookupCount + 1
        if lookupCount >= UInt16.max {
            lookupCount = 0
            completions.removeAll()
        }
    }
    
    
    /// 响应查询请求
    ///
    /// - Parameters:
    ///   - mess: dns message
    ///   - block: 如果是缓存中获取message 则这里需要传入
    private func response(_ mess: MQDNSMessage, _ block: MQDNSLookupCompletion? = nil) {
        
        var c = completions.removeValue(forKey: Int(mess.id))
        if c == nil {
            c = block
        }
        
        if c != nil, let answers = mess.answers {
            for a in answers {
                if a.type == 0x01 {
                    c?(a.data, nil)
                    break
                }
            }
        }
    }
    
    // MARK: - GCDAsyncUdpSocketDelegate
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?) {
        completions[tag]?(nil, error)
        completions.removeValue(forKey: tag)
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        let mess = MQDNSMessage.init(data: data)
        
        if let cache = cacheDict[GCDAsyncUdpSocket.host(fromAddress: address)!] {
            cache.resultDict[mess.qName] = mess
        } else {
            
            let cache = MQDNSCache()
            cache.server = GCDAsyncUdpSocket.host(fromAddress: address)!
            cache.resultDict[mess.qName] = mess
            
            cacheDict[cache.server] = cache
        }
        response(mess)
    }
}
