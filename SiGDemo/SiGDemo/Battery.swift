//
//  Battery.swift
//  SiGDemo
//
//  Created by Mark Zieg on 12/26/18.
//  Copyright © 2018 Wasatch Photonics. All rights reserved.
//

import Foundation
import UIKit

protocol BatteryDelegate: AnyObject
{
    func updateBattery(image: UIImage, sender: Battery)
    func updateBattery(chargeLevel: Double, charging: Bool)
}

class Battery
{
    var raw : UInt16 = 0
    var rawLevel: UInt8 = 0
    var rawState : UInt8 = 0
    var level : Double = 0.0
    
    var charging : Bool = false
    var delegate : BatteryDelegate?
    var initialized : Bool = false

    func parse(_ raw: UInt16)
    {
        rawState = UInt8((raw & 0xff00) >> 8)
        rawLevel = UInt8(raw & 0xff)

        // level = 100.0 * Double(rawLevel) / 255.0
        level = Double(rawLevel)
        
        charging = rawState & 1 == 1

        print("Battery.parse: \(self)")
        
        if let d = delegate
        {
            print("Battery.parse: updating delegate")
            d.updateBattery(chargeLevel: level, charging: charging)
            if let img = UIImage(named: getIconName())
            {
                d.updateBattery(image: img, sender: self)
            }
        }
        
        initialized = true
    }

    func getIconName() -> String
    {
        if charging
        {
            if level >= 98
            {
                return "Battery-Charging-Full"
            }
            else
            {
                return "Battery-Charging"
            }
        }
        else
        {
            if level >= 90
            {
                return "Battery-100"
            }
            else if level >= 70
            {
                return "Battery-80"
            }
            else if level >= 50
            {
                return "Battery-60"
            }
            else if level >= 30
            {
                return "Battery-40"
            }
            else if level >= 15
            {
                return "Battery-20"
            }
            else if level >= 5
            {
                return "Battery-Low"
            }
            else
            {
                return "Battery-Empty"
            }
        }
    }
}

extension Battery: CustomStringConvertible
{
    var description: String
    {
        return String(format: "raw %04x (lvl %d, st 0x%02x) = %.2f", raw, rawLevel, rawState, level)
    }
}
