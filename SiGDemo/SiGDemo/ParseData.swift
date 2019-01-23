//
//  ParseData.swift
//  SiGDemo
//
//  Created by Mark Zieg on 11/20/18.
//  Copyright © 2018 Wasatch Photonics. All rights reserved.
//

import Foundation

func parseBool(_ data: Data) -> Bool
{
    let buf = [UInt8](data)
    return buf[0] == 0
}

func parseUInt(lsb: Data) -> UInt
{
    let buf = [UInt8](lsb)
    
    // treat as little-endian (spectra)
    var value : UInt = 0
    for i in stride(from: lsb.count - 1, to: -1, by: -1)
    {
        value = (value << 8) | UInt(buf[i])
    }
    // print("parseUint: lsb -> buf \(buf) -> UInt \(value)")
    return value
}

func parseUInt(msb: Data) -> UInt
{
    let buf = [UInt8](msb)
    
    // treat as big-endian (SiG default)
    var value : UInt = 0
    for i in 0 ..< msb.count
    {
        value = (value << 8) | UInt(buf[i])
    }
    // print("parseUint: msb -> buf \(buf) -> UInt \(value)")
    return value
}

func parseFloat_NOT_USED(_ data: Data) -> Float
{
    let bits32 = UInt32(parseUInt(msb: data))
    let value = Float(bitPattern: bits32)
    // print("parseFloat: data \(data) -> float \(value)")
    return value
}

func parseFloatArray_NOT_USED(_ data: Data) -> [Float]
{
    var fa : [Float] = []
    
    let len = data.count
    if len % 4 != 0
    {
        print("parseFloatArray: ERROR: received float[] with length \(len) bytes")
        return fa
    }
    
    for i in stride(from: 0, to: len, by: 4)
    {
        fa.append(parseFloat_NOT_USED(data.subdata(in: i ..< (i+4))))
    }
    
    return fa
}
