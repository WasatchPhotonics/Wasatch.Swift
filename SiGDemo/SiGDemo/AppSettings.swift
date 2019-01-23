//
//  AppSettings.swift
//  SiGDemo
//
//  Created by Mark Zieg on 1/21/19.
//  Copyright © 2019 Wasatch Photonics. All rights reserved.
//

import Foundation
import os.log

struct PropertyKey
{
    static let uuidToSerial = "uuidToSerial"
    static let lastUUID = "lastUUID"
}

/// see https://developer.apple.com/library/archive/referencelibrary/GettingStarted/DevelopiOSAppsSwift/PersistData.html
/// update to Codable?
class AppSettings : NSObject, NSCoding
{
    static let documentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let archiveURL = documentsDirectory.appendingPathComponent("SiGDemoAppSettings")
    
    // not sure I want to get into official Xcode / App Store versioning yet
    static let version = "1.0.2"
    
    var uuidToSerial : [String:String] = [:]
    var lastUUID : String?

    required convenience init?(coder aDecoder: NSCoder)
    {
        self.init()
        lastUUID = aDecoder.decodeObject(forKey: PropertyKey.lastUUID) as? String
        uuidToSerial = aDecoder.decodeObject(forKey: PropertyKey.uuidToSerial) as? [String:String] ?? [:]
    }

    func encode(with aCoder: NSCoder)
    {
        aCoder.encode(lastUUID, forKey: PropertyKey.lastUUID)
        aCoder.encode(uuidToSerial, forKey: PropertyKey.uuidToSerial)
    }
}
