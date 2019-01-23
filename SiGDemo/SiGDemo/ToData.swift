//
//  ToData.swift
//  SiGDemo
//
//  Created by Mark Zieg on 11/20/18.
//  Copyright © 2018 Wasatch Photonics. All rights reserved.
//

// This file provides a set of functions used to convert basic datatypes into
// the Data[] arrays used by CoreBluetooth.  It will primarily (exclusively?) be
// used by Spectrometer to send commands and requests to the SiG over BLE.
//
// It is thus "sort of" an
// opposite to Unpacker, except that while EEPROM/Unpacker are indeed
// demarshalling fields sent as Data[] EEPROM pages, the formatting of the
// fields within the pages themselves is very much "bog-standard" across all
// WP spectrometers and communication buses.  Therefore, while Unpacker is
// technically deserializing native types from BLE Data[], the fields weren't
// necessarily serialized according to any conventions relevant to BLE or the
// SiG's unique API.
//
// Therefore, don't make any assumptions about the endian ordering or framing
// conventions of this file necessarily mapping to the behavior of that class.
//
// This file is specifically designed to marshal data values being sent via BLE
// to the "BLE ARM controller" on the SiG unit.  Therefore it will generally use
// big-endian ordering (as adopted by the SiG BLE protocol).
//
// There shouldn't be very many datatypes defined here, because SiGDemo "sends"
// relatively little data "to" the SiG — most of the traffic flows in the other
// direction.
//
// TODO:
// - refactor to static class functions
// - confirm which signatures we actually need

import Foundation

func toData(bool: Bool) -> Data
{
    var bytes : [UInt8] = []
    bytes.append(UInt8(bool ? 1 : 0))
    let data = Data(bytes)
    print("ToData: bool \(bool) -> data \(data)")
    return data
}

func toData(byte1: UInt8, byte2: UInt8) -> Data
{
    let word = (UInt(byte1) << 8) | UInt(byte2)
    return toData(uint: word, len: 2)
}

func toData(uint: UInt, len: Int) -> Data
{
    var bytes = [UInt8](repeating: 0, count: len)

    // generate MSB-to-LSB order
    var v = uint
    for i in stride(from: len - 1, to: -1, by: -1)
    {
        bytes[i] = UInt8(v & 0xff)
        v = v >> 8
    }
    let data = Data(bytes)
    print("uintToData: uint \(uint) -> data \(data)")
    return data
}

func toData_NOT_USED(float: Float) -> Data
{
    let bits32 : UInt32 = float.bitPattern
    var bytes : [UInt8] = []
    
    // big-endian
    bytes.append(UInt8((bits32 >> 24) & 0xff))
    bytes.append(UInt8((bits32 >> 16) & 0xff))
    bytes.append(UInt8((bits32 >>  8) & 0xff))
    bytes.append(UInt8( bits32        & 0xff))

    let data = Data(bytes)
    print("floatToData: float \(float) -> bits32 \(bits32) -> data \(data)")
    
    return data
}
