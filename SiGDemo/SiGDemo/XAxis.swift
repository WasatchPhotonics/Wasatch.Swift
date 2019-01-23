//
//  XAxis.swift
//  SiGDemo
//
//  Created by Mark Zieg on 12/28/18.
//  Copyright © 2018 Wasatch Photonics. All rights reserved.
//

import Foundation

class XAxis
{
    enum Types
    {
        case PIXEL
        case WAVELENGTH
        case WAVENUMBER
    }

    var type: Types = .PIXEL
    static let labels = ["Pixel", "Wavelength", "Wavenumber"]
    
    init(_ type: Types)
    {
        self.type = type
    }
    
    static func labelToEnum(_ label: String) -> Types
    {
        switch label
        {
            case labels[1]: return .WAVELENGTH
            case labels[2]: return .WAVENUMBER
            default: return .PIXEL
        }
    }
    
    static func enumToLabel(_ value: Types) -> String
    {
        switch value
        {
            case .PIXEL: return labels[0]
            case .WAVELENGTH: return labels[1]
            case .WAVENUMBER: return labels[2]
        }
    }
}

extension XAxis: CustomStringConvertible
{
    var description: String
    {
        return XAxis.enumToLabel(type)
    }
}
