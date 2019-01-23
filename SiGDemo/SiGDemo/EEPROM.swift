//
//  EEPROM.swift
//  SiGDemo
//
//  Created by Mark Zieg on 12/18/18.
//  Copyright © 2018 Wasatch Photonics. All rights reserved.
//

import Foundation

/// - used by Spectrometer
class EEPROM
{
    static let PAGE_COUNT : Int = 6 // really 8, last two currently unused
    static let PAGE_SIZE : Int = 64
    static let SUBPAGE_COUNT : Int = 4
    static let SUBPAGE_SIZE : Int = PAGE_SIZE / SUBPAGE_COUNT

    // metadata representing the state of the incremental load over BLE
    var readStarted = false
    var readFinished = false
    var pageIndex : Int = 0
    var subpageIndex : Int = 0
    
    // raw date read from spectrometer
    var pages : [[UInt8]] = Array(repeating: Array(repeating: 0, count: PAGE_SIZE), count: PAGE_COUNT)
    
    // metadata for UI
    var displayable : [Int:[String:String]] = [:]
    var displayKeys : [Int:[String]] = [:]

    // actual EEPROM fields
    var format                      : UInt8 = 4
    var model                       : String = "unknown"
    var serial_number               : String = "unknown"
    var baud_rate                   : UInt32 = 0
    var has_cooling                 : Bool = false
    var has_battery                 : Bool = false
    var has_laser                   : Bool = false
    var excitation_nm               : UInt16 = 0
    var slit_size_um                : UInt16 = 0
    var startup_integration_time_ms : UInt16 = 10
    var startup_temp_degC           : Int16 = 15
    var startup_triggering_scheme   : UInt8 = 0
    var detector_gain               : Float = 1.9
    var detector_offset             : Int16 = 0
    var detector_gain_odd           : Float = 1.9
    var detector_offset_odd         : Int16 = 0

    var wavelength_coeffs           : [Float]? = nil
    var degC_to_dac_coeffs          : [Float]? = nil
    var adc_to_degC_coeffs          : [Float]? = nil
    var max_temp_degC               : Int16 = 20
    var min_temp_degC               : Int16 = 10
    var tec_r298                    : Int16 = 0
    var tec_beta                    : Int16 = 0
    var calibration_date            : String? = nil
    var calibrated_by               : String? = nil
    
    var detector                    : String? = nil
    var active_pixels_horizontal    : UInt16 = 0
    var active_pixels_vertical      : UInt16 = 0
    var min_integration_time_ms     : UInt16 = 1
    var max_integration_time_ms     : UInt16 = 60000
    var actual_pixels_horizontal    : UInt16 = 0
    var roi_horizontal_start        : UInt16 = 0
    var roi_horizontal_end          : UInt16 = 0
    var roi_vertical_region_1_start : UInt16 = 0
    var roi_vertical_region_1_end   : UInt16 = 0
    var roi_vertical_region_2_start : UInt16 = 0
    var roi_vertical_region_2_end   : UInt16 = 0
    var roi_vertical_region_3_start : UInt16 = 0
    var roi_vertical_region_3_end   : UInt16 = 0
    var linearity_coeffs            : [Float]? = nil
    
    var max_laser_power_mW          : Float = 0.0
    var min_laser_power_mW          : Float = 0.0
    var laser_power_coeffs          : [Float]? = nil
    var excitation_nm_float         : Float = 0.0
    
    var user_data                   : [UInt8]? = nil
    var user_text                   : String? = nil
    
    var bad_pixels                  : [Int]? = Array(repeating: -1, count: 15)

    init()
    {
        clear()
    }
    
    func clear()
    {
        readStarted = false
        readFinished = false
        pageIndex = 0
        subpageIndex = 0
        pages = Array(repeating: Array(repeating: 0, count: EEPROM.PAGE_SIZE), count: EEPROM.PAGE_COUNT)
    }
    
    func storeSubpage(_ data: Data) -> Bool
    {
        if pageIndex >= EEPROM.PAGE_COUNT
        {
            print("ERROR: can't store to EEPROM page \(pageIndex)")
            return false
        }
        
        print("Subpage[\(pageIndex)][\(subpageIndex)]: ", terminator: "")
        for i in 0 ..< EEPROM.SUBPAGE_SIZE
        {
            let offset = subpageIndex * EEPROM.SUBPAGE_SIZE + i
            if offset < EEPROM.PAGE_SIZE
            {
                let byte = UInt8(data[i])

                let hex = String(format:"%02x", byte)
                print(" \(hex)", terminator: "")
                
                pages[pageIndex][offset] = byte
            }
            else
            {
                print("ERROR: can't store to offset \(offset) of EEPROM page \(pageIndex)")
                return false
            }
        }
        print()
        return true
    }

    func incrSubpage() -> Bool
    {
        subpageIndex = (subpageIndex + 1) % EEPROM.SUBPAGE_COUNT
        if subpageIndex == 0
        {
            pageIndex = (pageIndex + 1) % EEPROM.PAGE_COUNT
        }
        
        return subpageIndex == 0 && pageIndex == 0
    }

    func parse()
    {
        let unpacker = Unpacker(pages)
        
        ////////////////////////////////////////////////////////////////////////
        // Page 0
        ////////////////////////////////////////////////////////////////////////

        model                           = unpacker.unpack(s: (0,  0, 16))
        serial_number                   = unpacker.unpack(s: (0, 16, 16))
        baud_rate                       = unpacker.unpack(I: (0, 32,  4))
        has_cooling                     = unpacker.unpack(q: (0, 36,  1))
        has_battery                     = unpacker.unpack(q: (0, 37,  1))
        has_laser                       = unpacker.unpack(q: (0, 38,  1))
        excitation_nm                   = unpacker.unpack(H: (0, 39,  2))
        slit_size_um                    = unpacker.unpack(H: (0, 41,  2))
        
        format                          = unpacker.unpack(B: (0, 63,  1))

        if format >= 4
        {
            startup_integration_time_ms = unpacker.unpack(H: (0, 43,  2))
            startup_temp_degC           = unpacker.unpack(h: (0, 45,  2))
            startup_triggering_scheme   = unpacker.unpack(B: (0, 47,  1))
            detector_gain               = unpacker.unpack(f: (0, 48,  4)) // "even pixels" for InGaAs
            detector_offset             = unpacker.unpack(h: (0, 52,  2)) // "even pixels" for InGaAs
            detector_gain_odd           = unpacker.unpack(f: (0, 54,  4)) // InGaAs-only
            detector_offset_odd         = unpacker.unpack(h: (0, 58,  2)) // InGaAs-only
        }

        ////////////////////////////////////////////////////////////////////////
        // Page 1
        ////////////////////////////////////////////////////////////////////////

        wavelength_coeffs = []
        wavelength_coeffs!        .append(unpacker.unpack(f: (1,  0,  4)))
        wavelength_coeffs!        .append(unpacker.unpack(f: (1,  4,  4)))
        wavelength_coeffs!        .append(unpacker.unpack(f: (1,  8,  4)))
        wavelength_coeffs!        .append(unpacker.unpack(f: (1, 12,  4)))
        degC_to_dac_coeffs = []                   
        degC_to_dac_coeffs!       .append(unpacker.unpack(f: (1, 16,  4)))
        degC_to_dac_coeffs!       .append(unpacker.unpack(f: (1, 20,  4)))
        degC_to_dac_coeffs!       .append(unpacker.unpack(f: (1, 24,  4)))
        adc_to_degC_coeffs = []                   
        adc_to_degC_coeffs!       .append(unpacker.unpack(f: (1, 32,  4)))
        adc_to_degC_coeffs!       .append(unpacker.unpack(f: (1, 36,  4)))
        adc_to_degC_coeffs!       .append(unpacker.unpack(f: (1, 40,  4)))
        max_temp_degC                   = unpacker.unpack(h: (1, 28,  2))
        min_temp_degC                   = unpacker.unpack(h: (1, 30,  2))
        tec_r298                        = unpacker.unpack(h: (1, 44,  2))
        tec_beta                        = unpacker.unpack(h: (1, 46,  2))
        calibration_date                = unpacker.unpack(s: (1, 48, 12))
        calibrated_by                   = unpacker.unpack(s: (1, 60,  3))
                                    
        ////////////////////////////////////////////////////////////////////////
        // Page 1
        ////////////////////////////////////////////////////////////////////////

        detector                        = unpacker.unpack(s: (2,  0, 16))
        active_pixels_horizontal        = unpacker.unpack(H: (2, 16,  2))
        active_pixels_vertical          = unpacker.unpack(H: (2, 19,  2)) // MZ: skipped 18
        min_integration_time_ms         = unpacker.unpack(H: (2, 21,  2))
        max_integration_time_ms         = unpacker.unpack(H: (2, 23,  2))
        actual_pixels_horizontal        = unpacker.unpack(H: (2, 25,  2))
        roi_horizontal_start            = unpacker.unpack(H: (2, 27,  2))
        roi_horizontal_end              = unpacker.unpack(H: (2, 29,  2))
        roi_vertical_region_1_start     = unpacker.unpack(H: (2, 31,  2))
        roi_vertical_region_1_end       = unpacker.unpack(H: (2, 33,  2))
        roi_vertical_region_2_start     = unpacker.unpack(H: (2, 35,  2))
        roi_vertical_region_2_end       = unpacker.unpack(H: (2, 37,  2))
        roi_vertical_region_3_start     = unpacker.unpack(H: (2, 39,  2))
        roi_vertical_region_3_end       = unpacker.unpack(H: (2, 41,  2))
        linearity_coeffs = []                     
        linearity_coeffs!         .append(unpacker.unpack(f: (2, 43,  4))) // overloading for secondary ADC
        linearity_coeffs!         .append(unpacker.unpack(f: (2, 47,  4)))
        linearity_coeffs!         .append(unpacker.unpack(f: (2, 51,  4)))
        linearity_coeffs!         .append(unpacker.unpack(f: (2, 55,  4)))
        linearity_coeffs!         .append(unpacker.unpack(f: (2, 59,  4)))

        ////////////////////////////////////////////////////////////////////////
        // Page 3
        ////////////////////////////////////////////////////////////////////////
        
        laser_power_coeffs = []
        laser_power_coeffs!       .append(unpacker.unpack(f: (3, 12,  4)))
        laser_power_coeffs!       .append(unpacker.unpack(f: (3, 16,  4)))
        laser_power_coeffs!       .append(unpacker.unpack(f: (3, 20,  4)))
        laser_power_coeffs!       .append(unpacker.unpack(f: (3, 24,  4)))
        max_laser_power_mW              = unpacker.unpack(f: (3, 28,  4))
        min_laser_power_mW              = unpacker.unpack(f: (3, 32,  4))
        excitation_nm_float             = unpacker.unpack(f: (3, 36,  4))

        ////////////////////////////////////////////////////////////////////////
        // Page 4
        ////////////////////////////////////////////////////////////////////////

        user_data = pages[4]
        user_text = unpacker.unpack(s: (4,  0, 63))

        ////////////////////////////////////////////////////////////////////////
        // Page 5
        ////////////////////////////////////////////////////////////////////////

        // ignore bad_pixels for now — inapplicable to Sony IMX anyway
        
        // generate displayable versions for logging and GUI
        makeDisplayable()
        log()
        
        // tested by Spectrometer.isInitialized()
        readFinished = true
	}
    
    func makeDisplayable()
    {
        displayable = [:]
        displayKeys = [:]
        for i in 0 ..< EEPROM.PAGE_COUNT
        {
            displayable[i] = [:]
            displayKeys[i] = [ ]
        }

        displayKeys[0] = [ "Model", "Serial Number", "Baud Rate",
            "Has Cooling", "Has Battery", "Has Laser", 
            "Excitation", "Slit size", 
            "Start Integ Time", "Start Temp", "Start Triggering",
            "Det Gain", "Det Offset", "Det Gain Odd", "Det Offset Odd" ]
        displayable[0]!["Model"] = model
        displayable[0]!["Serial Number"] = serial_number
        displayable[0]!["Baud Rate"] = String(baud_rate)
        displayable[0]!["Has Cooling"] = String(has_cooling)
        displayable[0]!["Has Battery"] = String(has_battery)
        displayable[0]!["Has Laser"] = String(has_laser)
        displayable[0]!["Excitation"] = String(excitation_nm)
        displayable[0]!["Slit size"] = String(slit_size_um)
        displayable[0]!["Start Integ Time"] = String(startup_integration_time_ms)
        displayable[0]!["Start Temp"] = String(startup_temp_degC)
        displayable[0]!["Start Triggering"] = String(startup_triggering_scheme)
        displayable[0]!["Det Gain"] = String(detector_gain)
        displayable[0]!["Det Offset"] = String(detector_offset)
        displayable[0]!["Det Gain Odd"] = String(detector_gain_odd)
        displayable[0]!["Det Offset Odd"] = String(detector_offset_odd)

        displayKeys[1] = [ "Wavecal coeffs", "degCToDAC coeffs", "adcToDegC coeffs",
            "Det temp max", "Det temp min", 
            "TEC R298", "TEC beta", 
            "Calibration Date", "Calibration By" ]
        displayable[1]!["Wavecal coeffs"] = String(describing: wavelength_coeffs)
        displayable[1]!["degCToDAC coeffs"] = String(describing: degC_to_dac_coeffs)
        displayable[1]!["adcToDegC coeffs"] = String(describing: adc_to_degC_coeffs)
        displayable[1]!["Det temp max"] = String(max_temp_degC)
        displayable[1]!["Det temp min"] = String(min_temp_degC)
        displayable[1]!["TEC R298"] = String(tec_r298)
        displayable[1]!["TEC beta"] = String(tec_beta)
        displayable[1]!["Calibration Date"] = String(calibration_date!)
        displayable[1]!["Calibration By"] = String(calibrated_by!)

        displayKeys[2] = [ "Detector name", "Active horiz", "Active vertical",
            "Min integration", "Max integration", 
            "Actual Pixels Horiz", "ROI Horiz Start", "ROI Horiz End", 
            "ROI Vert Reg 1 Start", "ROI Vert Reg 1 End", 
            "ROI Vert Reg 2 Start", "ROI Vert Reg 2 End", 
            "ROI Vert Reg 3 Start", "ROI Vert Reg 3 End", 
            "Linearity Coeffs" ]
        displayable[2]!["Detector name"] = String(String(detector!))
        displayable[2]!["Active horiz"] = String(active_pixels_horizontal)
        displayable[2]!["Active vertical"] = String(active_pixels_vertical)
        displayable[2]!["Min integration"] = String(min_integration_time_ms)
        displayable[2]!["Max integration"] = String(max_integration_time_ms)
        displayable[2]!["Actual Pixels Horiz"] = String(actual_pixels_horizontal)
        displayable[2]!["ROI Horiz Start"] = String(roi_horizontal_start)
        displayable[2]!["ROI Horiz End"] = String(roi_horizontal_end)
        displayable[2]!["ROI Vert Reg 1 Start"] = String(roi_vertical_region_1_start)
        displayable[2]!["ROI Vert Reg 1 End"] = String(roi_vertical_region_1_end)
        displayable[2]!["ROI Vert Reg 2 Start"] = String(roi_vertical_region_2_start)
        displayable[2]!["ROI Vert Reg 2 End"] = String(roi_vertical_region_2_end)
        displayable[2]!["ROI Vert Reg 3 Start"] = String(roi_vertical_region_3_start)
        displayable[2]!["ROI Vert Reg 3 End"] = String(roi_vertical_region_3_end)
        displayable[2]!["Linearity Coeffs"] = String(describing: linearity_coeffs)
       
        displayKeys[3] = [ "Laser coeffs", "Max Laser Power", "Min Laser Power", "Excitation (float)" ]
        displayable[3]!["Laser coeffs"] = String(describing: laser_power_coeffs)
        displayable[3]!["Max Laser Power"] = String(max_laser_power_mW)
        displayable[3]!["Min Laser Power"] = String(min_laser_power_mW)
        displayable[3]!["Excitation (float)"] = String(excitation_nm_float)
      
        displayKeys[4] = [ "User Text" ]
        displayable[4]!["User Text"] = String(user_text!)
     
        displayKeys[5] = [ "Bad Pixels" ]
        displayable[5]!["Bad Pixels"] = String(describing: bad_pixels)
    }
    
	func log()
	{
		print("EEPROM settings:")
        
        for i in 0 ..< EEPROM.PAGE_COUNT
        {
            print("  EEPROM Page \(i):")
            for j in 0 ..< displayKeys[i]!.count
            {
                let key = displayKeys[i]![j]
                let value = displayable[i]![key]
                print("    \(key): \(String(describing: value))")
            }
        }
	}
}
