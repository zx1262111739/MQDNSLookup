//
//  main.swift
//  MQDNSLookup
//
//  Created by AQY on 2018/6/12.
//

import Foundation

MQDNSLookup.default.lookup("www.baidu.com", server: "114.114.114.114") { (ip, err) in
    print("dns server 114.114.114.114")
    guard err == nil else {
        print(err!)
        return
    }
    print(ip)
}

MQDNSLookup.default.lookup("www.baidu.com") { (ip, err) in
    guard err == nil else {
        print(err!)
        return
    }
    print(ip)
}

RunLoop.main.run()
