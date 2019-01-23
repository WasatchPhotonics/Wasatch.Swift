//
//  Util.swift
//  SiGDemo
//
//  Created by Mark Zieg on 12/28/18.
//  Copyright © 2018 Wasatch Photonics. All rights reserved.
//

import Foundation

class Util
{
    static func printRange(label: String, array: [Double]?)
    {
        if array == nil
        {
            print("\(label) is nil")
        }
        else
        {
            let first = array![0]
            let last = array![array!.count - 1]
            print("\(label) has range (\(first), \(last))")
        }
    }
}
