//
//  Unpack.swift
//  SiGDemo
//
//  Created by Mark Zieg on 12/20/18.
//  Copyright © 2018 Wasatch Photonics. All rights reserved.
//

import Foundation

////////////////////////////////////////////////////////////////////////////
/// This class is used by EEPROM to deserialize packed data.
///
/// Functions are modeled on Python's unpack(); see
/// https://docs.python.org/2/library/struct.html#format-characters
///
/// Essentially, where Python sends a character code to indicate format of
/// the packed characters (and desired return datatype), I'm overloading the
/// parameter label with the same character to indicate the same type.
///
/// Note that while most SiG API comms are MSB-LSB, the EEPROM storage itself
/// is constant across all spectrometers, and therefore LSB-MSB (the x86
/// default).
////////////////////////////////////////////////////////////////////////////
class Unpacker
{
    let pages: [[UInt8]]
    
    init(_ pages: [[UInt8]])
    {
        self.pages = pages
        
        log()
    }
    
    func log()
    {
        for i in 0 ..< pages.count
        {
            print("Page \(i): ", terminator: "")
            for j in 0 ..< pages[i].count
            {
                print(String(format: " %02x", pages[i][j]), terminator: "")
            }
            print()
        }
    }
    
    private func toUInt64(_ tup: (Int, Int, Int)) -> UInt64
    {
        let page  = tup.0
        let start = tup.1
        let len   = tup.2

        var result : UInt64 = 0

        // let sequence = stride(from: 0, to: len, by: 1) // MSB-LSB
        let sequence = stride(from: len - 1, to: -1, by: -1) // LSB-MSB
        for i in sequence
        {
            result = (result << 8) | UInt64(pages[page][start + i])
        }
        
        return result
    }
    
    func unpack(I: (Int, Int, Int)) -> UInt32 { return UInt32(toUInt64(I)) }
    func unpack(i: (Int, Int, Int)) ->  Int32 { return  Int32(bitPattern: unpack(I: i)) }
    func unpack(H: (Int, Int, Int)) -> UInt16 { return UInt16(toUInt64(H)) }
    func unpack(h: (Int, Int, Int)) ->  Int16 { return  Int16(bitPattern: unpack(H: h)) }
    func unpack(B: (Int, Int, Int)) ->  UInt8 { return  UInt8(toUInt64(B)) }
    func unpack(b: (Int, Int, Int)) ->   Int8 { return   Int8(bitPattern: unpack(B: b)) }
    func unpack(f: (Int, Int, Int)) ->  Float { return  Float(bitPattern: unpack(I: f)) }
    
    /// Python uses "?" for bool, which obviously won't work here; use "q" instead
    func unpack(q: (Int, Int, Int)) ->   Bool { return toUInt64(q) != 0 }
    
    func unpack(s: (Int, Int, Int)) -> String
    {
        let page  = s.0
        let start = s.1
        let len   = s.2
        
        var result = ""
        for i in 0 ..< len
        {
            let byte = pages[page][start + i]
            if byte == 0
            {
                break
            }
            result += String(UnicodeScalar(byte))
        }
        
        return result
    }
}
