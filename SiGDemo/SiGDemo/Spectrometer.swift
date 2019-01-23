//
//  Spectrometer.swift
//  SiGDemo
//
//  Created by Mark Zieg on 11/15/18.
//  Copyright © 2018 Wasatch Photonics. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol SpectrumDelegate: AnyObject
{
    func processSpectrum(spectrum: [Double], done: Bool)
}

protocol EEPROMLoadDelegate: AnyObject
{
    func pairingStatus(started: Bool)
    func pairingStatus(percentage: Float)
    func pairingStatus(complete: Bool)
}

/// This class encapsulates communication and state of one connected
/// BLE spectrometer.
///
/// It is instantiated by the main ViewController for the app, which passes
/// references to the object into BLEViewController, ScopeViewController and
/// others.
///
/// At instantiation, it does not have a CoreBluetooth CBPeripheral and so is
/// non-functional.  The BLEViewController manages the pairing of the app and
/// a valid BLE peripheral advertising the correct services.  When a matching
/// peripheral is selected, the BLEViewController passes the CBPeripheral
/// reference to the global spectrometer object, making it functional.
///
/// BLEViewController is responsible for discovering services and characteristics;
/// as Characteristics are discovered, they are registered with the Spectrometer
/// instance.  The Spectrometer object sends writeValue() and readValue()
/// messages to the Characteristics, and when readValue responses come back from
/// the peripheral, they are forwarded here by the BLEViewController (which
/// remains the peripheral's delegate).
///
/// This class is then controlled and queried by other parts of the application
/// such as the ScopeViewController.  When new spectra are received and assembled
/// (over a series of BLE packets), each complete new spectrum is processed by
/// the current SpectrumProcessorDelegate (currently the ScopeViewController).
///
/// # Architectural TODO
///
/// We should really split this class into a SpectrometerController (which
/// handles connection of new CBPeripherals, initial CBCharacteristic setup) and
/// Spectrometer (which would be instanitated and provisioned by the
/// SpectrometerController "factory").
///
/// # uint vs int
///
/// I generally prefer using UInt for values where negatives make no sense (like
/// pixels, integration time, scans to average &c). However, Swift is ornery
/// about using uint as indexes in for loops and arrays, so I'm leaving most
/// things as Ints EXCEPT when converting BLE types over the wire, as I don't
/// want to imply that any of the conversions are safe for negatives (and ICDs
/// should be minimal and absolute).
///
/// # Lifecycle
///
/// A single Spectrometer object is created at app load, and is persisted
/// throughout the lifetime of the app.  Its main reference is held by the
/// BLEController, a persistent object created by the initial ViewController
/// and then passed to subsequent ViewControllers.
///
/// The fact that the Spectrometer object is non-nil does not mean you are
/// connected to a BLE peripheral; it is valid to "have" a non-nil Spectrometer
/// which nonetheless has a nil CBPeripheral, meaning you can't actually collect
/// data.
class Spectrometer
{
    ////////////////////////////////////////////////////////////////////////////
    // Properties
    ////////////////////////////////////////////////////////////////////////////
    
    /// observers/delegates
    var spectrumDelegate : SpectrumDelegate?
    var eepromLoadDelegate : EEPROMLoadDelegate?
    var batteryDelegate: BatteryDelegate?

    // Spectrometer has parent-reference to BLEController so it can tell
    // BLEController to save persisted settings after initialization is complete
    // (when we get EEPROM and SerialNumber).  AppSettings are at BLEController
    // level because they contain pre-pairing data about multiple Spectrometers.
    let bleController: BLEController
    var peripheral: CBPeripheral?
    var characteristicByName : [String:CBCharacteristic] = [:]
    var nameByCharacteristic : [CBCharacteristic:String] = [:]

    // initialization data
    var initialized = false
    
    var eeprom = EEPROM()

    // cached properties
    //
    // Could implement these as C#-style properties with get/set accessors, but
    // doing as functions for now
    var integrationTimeMS : Int = 10
    var gain : Int = 27
    var laserEnabled : Bool = false
    
    // cached EEPROM values
    var pixels : Int?

    // derived attributes
    var wavelengths : [Double]?
    var wavenumbers : [Double]?
    
    // spectrum in process of being read
    var partialSpectrum : [UInt]?
    var processedSpectrum : [Double]?
    var nextPacketCount : Int = 0
    var lastSpectrumPacketRequestTime = DispatchTime.now()
    var lastSpectrumRequestTime = DispatchTime.now()
    
    /// This often won't match the spectrometer's reported value, because the app
    /// value resets whenever the app is relaunched (though we could persist it),
    /// while the spectrometer version resets when it reboots (which given the
    /// battery, may not be for a very long time).  This is provided mainly for
    /// debugging, although we could presumably generate an "offset" from the
    /// FIRST spectra read from any given app launch, and then check for drops
    /// using that.
    var nextSpectrumCount : Int = 0

    // metadata (convenient to store in Spectrometer)
    var battery : Battery!
    var xAxis = XAxis(XAxis.Types.PIXEL)
    
    /// Display a partial spectrum after this many partial reads
    let PARTIAL_SPECTRUM_READS = 20
    
    /// see https://stackoverflow.com/questions/24003291/ifdef-replacement-in-the-swift-language
    let DEBUG = false

    ////////////////////////////////////////////////////////////////////////////
    // Lifecycle
    ////////////////////////////////////////////////////////////////////////////
    
    init(bleController: BLEController)
    {
        self.bleController = bleController
        
        clear()
    }
    
    func disconnect()
    {
        print("Spectrometer: disconnecting")
        peripheral = nil
        clear()
    }
    
    func setPeripheral(_ peripheral : CBPeripheral)
    {
        self.peripheral = peripheral
        clear()
    }
    
    /// This would be simpler if we split this class into a Spectrometer and
    /// SpectrometerController, where we could just instantiate a new
    /// Spectrometer when SpectrometerController received a new CBPeripheral
    func clear()
    {
        initialized = false
        
        eeprom.clear()
        
        laserEnabled = false
        
        pixels = nil
        gain = 27
        
        wavelengths = nil
        wavenumbers = nil
        
        partialSpectrum = nil
        processedSpectrum = nil
        
        nameByCharacteristic = [:]
        characteristicByName = [:]
        
        battery = Battery()

        nextSpectrumCount = 0
        nextPacketCount = 0
        print("Spectrometer: done clear")
    }
    
    func completeInitialization()
    {
        // complete the progress bar
        eepromLoadDelegate?.pairingStatus(percentage: 1.0)
        
        // parse EEPROM
        eeprom.parse()
        
        // cache important values
        pixels = Int(eeprom.active_pixels_horizontal)
        print("pixels = \(String(describing: pixels))")
        
        // persist UUID -> SerialNumber mapping
        bleController.persist(uuid: peripheral!.identifier.uuidString, serialNumber: eeprom.serial_number)
        
        // generate derived fields
        generateWavelengths()
        generateWavenumbers()
        
        // get initial battery state
        requestBatteryStatus()
        
        // request other initial state values
        // peripheral!.readValue(for: characteristicByName["gain"]!)
        // peripheral!.readValue(for: characteristicByName["integrationTimeMS"]!)
        
        // apply preferred defaults
        setIntegrationTime(ms: 400)
        setGain(24)
        
        // hide the progress bar after 0.5sec
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(500))
        {
            self.eepromLoadDelegate?.pairingStatus(complete: true)
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // BLEViewController callbacks (initialization)
    ////////////////////////////////////////////////////////////////////////////

    /// Called by BLEViewController when discovering an expected characteristic.
    func registerCharacteristic(_ name: String, _ characteristic: CBCharacteristic)
    {
        if peripheral == nil
        {
            print("ERROR: can't register characteristics without a peripheral")
            return
        }
        
        print("registered characteristic \(name)")
        characteristicByName[name] = characteristic
        nameByCharacteristic[characteristic] = name
        
        // whether eepromCmd or eepromData registers first, this will kick-off
        // the EEPROM load as soon as both are available
        if !eeprom.readStarted
            && characteristicByName["eepromCmd"] != nil
            && characteristicByName["eepromData"] != nil
        {
            initiateEEPROMRead()
        }
    }
    
    /// Called by BLEViewController, which serves as the CBPeripheralDelegate
    /// for the BLE device, when a requested characteristic read operation
    /// completes.
    func receiveValue(characteristic: CBCharacteristic)
    {
        if let name = nameByCharacteristic[characteristic]
        {
            print("received value for \(name)")
            if let data = characteristic.value
            {
                switch(name)
                {
                    case "pixels": print("spectrometer reports having \(Int(parseUInt(msb: data))) pixels")
                    case "integrationTimeMS": processReceivedIntegrationTime(data)
                    case "gain": processReceivedGain(data)
                    case "laserEnable": laserEnabled = parseBool(data)
                    case "batteryStatus": processReceivedBatteryStatus(data)
                    case "spectrum": processReceivedSpectrumPacket(data)
                    // case "eepromCmd": processReceivedEEPROMCmdAck(data)
                    case "eepromData": processReceivedEEPROMPacket(data)
                    default:
                        print("WARNING: no implementation provided for receivedValue(\(name))")
                }
                performInitializationCheck()
            }
            else
            {
                print("WARNING: received nil data for \(name)")
            }
        }
        else
        {
            print("ERROR: received value for unknown characteristic \(characteristic)")
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // Methods
    ////////////////////////////////////////////////////////////////////////////
    
    /// Just wraps the check in a void function as syntactic sugar
    func performInitializationCheck()
    {
        _ = isInitialized()
    }
    

    func isInitialized() -> Bool
    {
        if initialized
        {
            return true
        }
        
        var missing : String?
        if peripheral == nil
        {
            missing = "peripheral"
        }
        else if !eeprom.readFinished
        {
            missing = "EEPROM"
        }

        if missing == nil
        {
            print("Spectrometer successfully initialized")
            initialized = true
        }
        else
        {
            print("isInitialized: failed due to \(missing!)")
        }
        
        return initialized
    }
    
    func generateWavelengths()
    {
        wavelengths = nil
        
        if pixels == nil || pixels! <= 0
        {
            print("ERROR: can't generate wavelengths (no pixels)")
            return
        }
        
        if eeprom.wavelength_coeffs == nil || eeprom.wavelength_coeffs!.count != 4
        {
            print("ERROR: can't generate wavelengths (no coeffs)")
            return
        }
        
        if let c = eeprom.wavelength_coeffs
        {
            wavelengths = []
            for index in 0 ... pixels!
            {
                let i = Float(index)
                let x : Double = Double(c[0])
                               + Double(c[1] * i)
                               + Double(c[2] * i * i)
                               + Double(c[3] * i * i * i)
                wavelengths!.append(x)
            }

            if DEBUG
            {
                Util.printRange(label: "wavelengths", array: wavelengths)
            }

        }
        else
        {
            print("ERROR: can't generate wavelengths")
        }
    }
    
    func excitation() -> Float
    {
        var nm = Float(eeprom.excitation_nm)
        if eeprom.format >= 4
        {
            nm = eeprom.excitation_nm_float
        }
        print("using excitation = \(nm)")
        return nm
    }
    
    func generateWavenumbers()
    {
        wavenumbers = nil
        if (wavelengths == nil)
        {
            print("ERROR: can't generate wavenumbers (no wavelengths)")
            return
        }
        
        if excitation() <= 0
        {
            print("ERROR: can't generate wavenumbers (no excitation)")
            return
        }
        
        wavenumbers = []
        let base = 1e7 / Double(excitation())
        for i in 0 ... Int(pixels!)
        {
            wavenumbers!.append(wavelengths![i] != 0 ? (base - 1e7/wavelengths![i]) : 0)
        }
        
        if DEBUG
        {
            Util.printRange(label: "wavenumbers", array: wavenumbers)
        }
    }
    
    func processReceivedIntegrationTime(_ data: Data)
    {
        integrationTimeMS = Int(parseUInt(msb: data))
        print("integrationTimeMS <- \(integrationTimeMS)")
    }
    
    func processReceivedGain(_ data: Data)
    {
        gain = Int(parseUInt(msb: data))
        print("gain <- \(gain)")
    }

    ////////////////////////////////////////////////////////////////////////////
    // Battery
    ////////////////////////////////////////////////////////////////////////////

    func requestBatteryStatus()
    {
        peripheral?.readValue(for: characteristicByName["batteryStatus"]!)
    }
    
    func processReceivedBatteryStatus(_ data: Data)
    {
        let raw = UInt16(parseUInt(msb: data.subdata(in: 0 ..< 2)))
        battery.parse(raw)
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // EEPROM
    ////////////////////////////////////////////////////////////////////////////

    func initiateEEPROMRead()
    {
        eeprom.readStarted = true
        eeprom.readFinished = false
        
        eeprom.pageIndex = 0
        eeprom.subpageIndex = 0
        
        requestEEPROMSubpage()
        
        eepromLoadDelegate?.pairingStatus(started: true)
    }

    /// some obvious potential simplifications to this process:
    ///
    /// - collapse eepromCmd and eepromData to a single read/write
    ///   characteristic, rather than one for read and one for write
    /// - obviate eepromCmd altogether, and have the SiG "default"
    ///   to (page, subpage) of (0, 0), and simply support rollover
    ///   such that every 8 * 4 = 32 reads, it simply resets
    /// - consider returning 18 bytes from eepromData rather than 16,
    ///   so that (page, subpage) are always indicated in the header
    /// - retain eepromCmd, but merely to initialize the pair; otherwise,
    ///   have the SiG firmware auto-increment subpage on each read, such
    ///   that only a single eepromCmd is required to kick-off a read
    ///   sequence from a known position
    func requestEEPROMSubpage()
    {
        // tell the SiG which page and subpage we want to read next
        print("requestEEPROMSubpage \(eeprom.pageIndex), \(eeprom.subpageIndex)")
        let data = toData(byte1: UInt8(eeprom.pageIndex), byte2: UInt8(eeprom.subpageIndex))
        peripheral!.writeValue(data,
                               for: characteristicByName["eepromCmd"]!,
                               type: bleController.writeType())

        // now read the requested page/subpage
        peripheral!.readValue(for: characteristicByName["eepromData"]!)
    }

    func processReceivedEEPROMPacket(_ data: Data)
    {
        print("processReceivedEEPROMPacket: page \(eeprom.pageIndex), subpage \(eeprom.subpageIndex), data \(data)")

        if data.count != EEPROM.SUBPAGE_SIZE
        {
            print("processReceivedEEPROMPacket: ERROR (invalid length)")
            return
        }

        if !eeprom.storeSubpage(data)
        {
            print("processReceivedEEPROMPacket: failed to store subpage")
            return
        }

        let completionPercentage = (Float(eeprom.pageIndex) + Float(eeprom.subpageIndex) / Float(EEPROM.SUBPAGE_COUNT)) / Float(EEPROM.PAGE_COUNT)
        print("processReceivedEEPROMPacket: \(completionPercentage)% complete")
        eepromLoadDelegate?.pairingStatus(percentage: completionPercentage)

        // was this the last EEPROM packet, or is there more to read?
        let done = eeprom.incrSubpage()
        if done
        {
            completeInitialization()
        }
        else
        {
            // request next chunk
            requestEEPROMSubpage()
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    // Characteristic setters
    ////////////////////////////////////////////////////////////////////////////

    func setGain(_ n: Int)
    {
        let name = "gain"
        gain = n
        print("\(name) -> \(n)")

        if let characteristic = characteristicByName[name]
        {
            peripheral!.writeValue(toData(uint: UInt(n), len: 1),
                                   for: characteristic,
                                   type: bleController.writeType())
        }
        else
        {
            print("ERROR: can't write unregistered characteristic \(name)")
        }
    }

    func setIntegrationTime(ms: Int)
    {
        let name = "integrationTimeMS"
        integrationTimeMS = ms
        print("\(name) -> \(ms)")

        if let characteristic = characteristicByName[name]
        {
            peripheral!.writeValue(toData(uint: UInt(ms), len: 4),
                                   for: characteristic,
                                   type: bleController.writeType())
        }
        else
        {
            print("ERROR: can't write unregistered characteristic \(name)")
        }
    }
    
    func setLaserEnabled(_ flag: Bool)
    {
        let name = "laserEnable"
        laserEnabled = flag
        print("\(name) -> \(flag)")

        if let characteristic = characteristicByName[name]
        {
            peripheral!.writeValue(toData(bool: flag),
                                   for: characteristic,
                                   type: bleController.writeType())
        }
        else
        {
            print("ERROR: can't write unregistered characteristic \(name)")
        }
        
        requestBatteryStatus()
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // getSpectrum
    ////////////////////////////////////////////////////////////////////////////
    
    /// This method is called by the ScopeViewController when the "Sample"
    /// button is clicked, and eventually in other parts of the application when
    /// a new spectrum is required.  Note that this is not a blocking method,
    /// and returns nothing; it initiates the sequence of events that will
    /// eventually yield a spectrum which will be sent to the Spectrometer's
    /// SpectrumProcessorDelegate at that time.
    func requestSpectrum()
    {
        if !isInitialized()
        {
            print("requestSpectrum: Spectrometer not initialized, so generating fake spectrum")
            receiveFakeSpectrum()
            return
        }
        
        // send the acquire command
        let data = toData(bool: true)
        peripheral!.writeValue(data,
                               for: characteristicByName["acquireSpectrum"]!,
                               type: bleController.writeType())

        partialSpectrum = []
        
        // look for start-of-frame
        nextPacketCount = 0
        print("requestSpectrum: resetting nextPacketCount from \(nextPacketCount) to zero")
        
        // request first read, AFTER integration has had time to complete
        print("requestSpectrum: queuing first read in \(integrationTimeMS)ms")
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(integrationTimeMS))
        {
            print("requestSpectrum: requesting read of first spectrum packet")
            
            self.lastSpectrumRequestTime = DispatchTime.now()
            self.lastSpectrumPacketRequestTime = DispatchTime.now()
            
            // fire-off initial read of the presumed first packet
            self.peripheral!.readValue(for: self.characteristicByName["spectrum"]!)
        }
    }
    
    /// This method is received when a single packet of spectrum data has been
    /// received by the app from the BLE peripheral.  It is responsible for
    /// assembling the parts of the spectrum into a whole, and calling
    /// processReceivedSpectrum() when a complete spectrum is ready for post-
    /// processing.
    func processReceivedSpectrumPacket(_ data : Data)
    {
        let len = data.count
        // print("processReceivedSpectrumPacket: data = \(data), len = \(len)")
        if len < 4 || len % 2 != 1
        {
            print("processReceivedSpectrumPacket: ERROR (invalid length)")
            return
        }
        
        let now = DispatchTime.now()
        var elapsedMS = (Double(now.uptimeNanoseconds) - Double(lastSpectrumPacketRequestTime.uptimeNanoseconds)) / 1000000.0
        
        let packetCount = Int(parseUInt(msb: data.subdata(in: 0 ..< 1)))
        let spectrumCount = Int(parseUInt(msb: data.subdata(in: 1 ..< 2)))
        // ignore reserved 3rd byte (index 2)
        
        print("processReceivedSpectrumPacket: spectrumCount \(spectrumCount), packetCount \(packetCount) (expected \(nextSpectrumCount), \(nextPacketCount)); metrics BLE \(elapsedMS) ms")
        
        // Somehow we received the start of a new spectrum.  Just go with it for
        // error recovery.  Dump whatever we had in the buffer and start anew.
        if packetCount == 0 && nextPacketCount > 0
        {
            print("Discarding incomplete partial spectrum")
            nextPacketCount = 0
        }
        
        if packetCount != nextPacketCount
        {
            print("processReceivedSpectrumPacket: WARNING: received packetCount \(packetCount), expected \(nextPacketCount)")
        }
        
        var subspectrum : [UInt] = []
        var index = 3
        while index + 1 < len
        {
            // subspectrum.append(parseUInt(msb: data.subdata(in: index ..< index + 2)))
            subspectrum.append(parseUInt(lsb: data.subdata(in: index ..< index + 2)))
            index += 2
        }
        
        print("processReceivedSpectrumPacket: received spectrumCount \(spectrumCount), packetCount \(packetCount), intensities \(subspectrum)")
        partialSpectrum?.append(contentsOf: subspectrum)
        let done = partialSpectrum!.count >= pixels!
        
        aggregatePartialSpectrum()
        
        if done || packetCount % PARTIAL_SPECTRUM_READS == 0
        {
            sendProcessedSpectrumToDelegate(done)
        }

        // did we just finish a spectrum?
        if done
        {
            elapsedMS = (Double(DispatchTime.now().uptimeNanoseconds) - Double(lastSpectrumRequestTime.uptimeNanoseconds)) / 1000000.0

            // yes, this should be the last packet of the sequence
            print("processReceivedSpectrumPacket: end of spectrum detected, no further reads; metrics total BLE+display \(elapsedMS) ms")

            // prepare for next sequence
            nextSpectrumCount += 1
            nextPacketCount = 0
            
            requestBatteryStatus()
        }
        else
        {
            // nope, should be more to come
            nextPacketCount = packetCount + 1
            
            self.lastSpectrumPacketRequestTime = DispatchTime.now()

            // kick-off the next read
            peripheral!.readValue(for: characteristicByName["spectrum"]!)
        }
        
        elapsedMS = (Double(DispatchTime.now().uptimeNanoseconds) - Double(now.uptimeNanoseconds)) / 1000000.0
        print("metrics: processed packet in \(elapsedMS) ms")

    }
    
    /// This could be made more efficient by tracking where we are and just
    /// appending new values.
    func aggregatePartialSpectrum()
    {
        processedSpectrum = []
        if partialSpectrum == nil
        {
            print("No partialSpectrum to process")
            return
        }
        
        // convert raw UInt[] to Double[]; later we can worry about boxcar, dark
        // correction, client-side averaging and other post-processing
        for i in 0 ..< pixels!
        {
            if i >= partialSpectrum!.count
            {
                processedSpectrum!.append(0.0)
            }
            else if i < 4
            {
                processedSpectrum!.append(Double(partialSpectrum![4]))
            }
            else if i + 4 >= pixels!
            {
                processedSpectrum!.append(Double(partialSpectrum![pixels! - 5]))
            }
            else
            {
                processedSpectrum!.append(Double(partialSpectrum![i]))
            }
        }
    }
    
    func sendProcessedSpectrumToDelegate(_ done : Bool)
    {
        if let delegate = spectrumDelegate
        {
            if false && DEBUG
            {
                let len = processedSpectrum!.count
                let strArray : [String] = processedSpectrum!.compactMap { String($0) }
                let delimited = strArray.joined(separator: ", ")
                print("sendProcessedSpectrumToDelegate (\(len) pixels): \(delimited)")
            }
            delegate.processSpectrum(spectrum: processedSpectrum!, done: done)
        }
        else
        {
            print("Have no processing delegate, so leaving processed spectrum on the floor")
        }
    }
    
    func receiveFakeSpectrum()
    {
        print("Generating fake spectrum")
        processedSpectrum = FakeSpectrometer.getSpectrum(
            integrationTimeMS: integrationTimeMS,
            gain: gain,
            laserEnabled: laserEnabled)
        
        sendProcessedSpectrumToDelegate(true)
    }
}
