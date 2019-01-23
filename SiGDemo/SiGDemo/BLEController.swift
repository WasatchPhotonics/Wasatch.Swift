//
//  BLEController.swift
//  SiGDemo
//
//  Created by Mark Zieg on 11/20/18.
//  Copyright © 2018 Wasatch Photonics. All rights reserved.
//

import Foundation
import CoreBluetooth

/// This is a BLE Wasatch spectrometer we've "seen" during a recent scan by the
/// CoreBluetooth CentralManager.  Note it must be a class rather than struct
/// for pass-by-reference :-)
class SpectrometerSeenRec
{
    var peripheral : CBPeripheral
    var lastSeen : Date
    var lastRSSI : Double
    
    init(_ peripheral: CBPeripheral, RSSI: NSNumber)
    {
        self.peripheral = peripheral
        lastSeen = Date()
        lastRSSI = RSSI.doubleValue
    }
}

/// BLEController delegates (observers) like BLEViewController must implement
/// this interface.
protocol BLEControllerViewDelegate: AnyObject
{
    func showAlertMessage(_ message : String)
    func reloadTableData()
    func enableDisconnect(_ flag: Bool)
    
    // TODO: add func displayPaired(uuid) to colorize the currently-paired device
    //       add func unpair()?
}

/// This has to be an application-level "global" object so that it doesn't
/// go out-of-scope and delete itself.
///
/// The BLEController and the Spectrometer are conjoined (Spectrometer can't do
/// squat without its CBPeripheral, which the BLEController owns and supports as
/// delegate).
///
/// - the two need to maintain persistence throughout the lifetime of the app
/// - might as well let one hold the other so we only have one object to persist
/// - .^. the BLEController owns the Spectrometer instance
class BLEController :
    NSObject,
    CBCentralManagerDelegate,
    CBPeripheralDelegate
{
    ////////////////////////////////////////////////////////////////////////////
    // constants
    ////////////////////////////////////////////////////////////////////////////
    
    /// Of those devices advertising sigPrimaryService, only recognize devices
    /// with this advertisedName
    let spectrometerName = "WP-SiG"
    
    /// BLE Service UUID.  Note that CoreBluetooth requires hyphens when using
    /// long-form UUIDs, while pybleno requires their absence.
    ///
    /// was: sigPrimaryService = CBUUID(string: "9ca53b50-dd38-11e8-99e0-bff35b7f02d9")
    let sigPrimaryService = CBUUID(string: "ff00")

    /// scan for this long each "active scanning" period
    let timerScanIntervalSec: TimeInterval = 2.0
    
    /// pause this long between active scans to conserve battery
    let timerPauseIntervalSec: TimeInterval = 10.0

    /// If a spectrometer hasn't been seen in this many seconds, drop it from
    /// the table
    let EXPIRE_SPECTROMETERS_SEC = 12.0

    ////////////////////////////////////////////////////////////////////////////
    // properties
    ////////////////////////////////////////////////////////////////////////////
    
    // Oddly, doesn't need to hold a reference to the connected CBPeripheral;
    // we have references to the characteristics with which we communicate, and
    // the centralManager has a reference to the CBPeripheral, which in turn has
    // a reference to US as its delegate.  (Anyway, Spectrometer has reference
    // to the CBPeripheral.)

    var centralManager: CBCentralManager!
    
    var spectrometer: Spectrometer!
    
    var keepScanning = false

    var seenSpectrometers: [String: SpectrometerSeenRec] = [:] // key: uuidString
    var uuidByName : [String: CBUUID] = [:] // key: characteristic "human name"
    
    var viewDelegate : BLEControllerViewDelegate?
    
    var appSettings : AppSettings?
    
    var requireResponse = false

    ////////////////////////////////////////////////////////////////////////////
    // lifecycle
    ////////////////////////////////////////////////////////////////////////////

    override init()
    {
        super.init()
        
        appSettings = loadAppSettings()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        spectrometer = Spectrometer(bleController: self)

        // characteristics
        uuidByName["pixels"]                 = CBUUID(string: "ff01") // not used, but to avoid runtime comms warning
        uuidByName["integrationTimeMS"]      = CBUUID(string: "ff02")
        uuidByName["gain"]                   = CBUUID(string: "ff03")
        uuidByName["laserEnable"]            = CBUUID(string: "ff04")
        uuidByName["acquireSpectrum"]        = CBUUID(string: "ff05")
        uuidByName["spectrum"]               = CBUUID(string: "ff06")
        uuidByName["eepromCmd"]              = CBUUID(string: "ff07")
        uuidByName["eepromData"]             = CBUUID(string: "ff08")
        uuidByName["batteryStatus"]          = CBUUID(string: "ff09")
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // methods
    ////////////////////////////////////////////////////////////////////////////
    
    func writeType() -> CBCharacteristicWriteType
    {
        return requireResponse ? CBCharacteristicWriteType.withResponse : CBCharacteristicWriteType.withoutResponse
    }
    
    func expireOldSpectrometers()
    {
        var dropUuids : [String] = []
        for (uuid, rec) in seenSpectrometers
        {
            let sec = Date().timeIntervalSince(rec.lastSeen)
            if sec > EXPIRE_SPECTROMETERS_SEC
            {
                dropUuids.append(uuid)
            }
        }
        
        for uuid in dropUuids
        {
            seenSpectrometers.removeValue(forKey: uuid)
        }
    }
    
    /// BLE scanning is a battery hog, so set wipers to "intermittent"
    @objc func pauseScan()
    {
        print("pausing scan...")
        _ = Timer(timeInterval: timerPauseIntervalSec,
                  target: self,
                  selector: #selector(resumeScan),
                  userInfo: nil,
                  repeats: false)
        centralManager.stopScan()
        expireOldSpectrometers()
    }
    
    @objc func resumeScan()
    {
        expireOldSpectrometers()
        if keepScanning
        {
            // Start scanning again...
            print("resuming scan")
            _ = Timer(timeInterval: timerScanIntervalSec,
                      target: self,
                      selector: #selector(pauseScan),
                      userInfo: nil,
                      repeats: false)
            centralManager.scanForPeripherals(withServices: nil, options: nil)
            viewDelegate?.enableDisconnect(false)
        }
        else
        {
            viewDelegate?.enableDisconnect(true)
        }
    }
    
    /// STEP 6. The user responded "Yes" to the dialog presented by didSelectRowAt,
    /// so formally pair to the spectrometer.
    func pair(_ uuid: String)
    {
        if seenSpectrometers[uuid] == nil
        {
            fatalError("can't pair to unrecognized UUID")
        }
        let rec = seenSpectrometers[uuid]!
        
        // will trigger the centralManager(didConnect) callback if successful
        print("connecting to \(String(describing: rec.peripheral.name))")
        centralManager.connect(rec.peripheral, options: nil)
    }
    
    /// TableViews think in terms of row number, while we want to store seen
    /// spectrometers in a dictionary, so provide a deterministic mapping from
    /// row number to seen spectrometer.  Probably a slicker way to do this.
    func getOrderedSpectrometer(index: Int) -> SpectrometerSeenRec?
    {
        print("getOrderedSpectrometer(\(index))")
        var i = 0
        var rec : SpectrometerSeenRec? = nil
        for key in seenSpectrometers.keys.sorted()
        {
            if i == index
            {
                rec = seenSpectrometers[key]
                break
            }
            i = i + 1
        }
        return rec
    }
    
    /// STEP 1. Triggered when device Bluetooth turned on/off; also at class
    /// instantiation. Borrowed from https://github.com/cloudcity/ZeroToBLE-Part2-Swift
    func centralManagerDidUpdateState(_ central: CBCentralManager)
    {
        var message : String?
        
        switch central.state
        {
            case .poweredOff:   message = "Bluetooth on this device is currently powered off."
            case .unsupported:  message = "This device does not support Bluetooth Low Energy."
            case .unauthorized: message = "This app is not authorized to use Bluetooth Low Energy."
            case .resetting:    message = "The BLE Manager is resetting; a state update is pending."
            case .unknown:      message = "The state of the BLE Manager is unknown."
            case .poweredOn:
                print("Bluetooth LE is turned on and ready for communication.")
                keepScanning = true
                
                // after scanning for "timerScanIntervalSec", pause the scan briefly to conserve power
                _ = Timer(timeInterval: timerScanIntervalSec,
                          target: self,
                          selector: #selector(pauseScan),
                          userInfo: nil,
                          repeats: false)
                
                print("BLEController.didUpdateState: scanning for peripherals with primary service \(sigPrimaryService)")
                centralManager.scanForPeripherals(withServices: [sigPrimaryService])
        }
        
        if message != nil
        {
            print("CenteralManagerDidUpdateState: \(message!)")
            viewDelegate?.showAlertMessage(message!)
        }
    }
    
    /// STEP 2. called when a matching BLE device is discovered during scan
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber)
    {
        // get peripheral name
        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        {
            let uuid = peripheral.identifier.uuidString
            print("BLEController.didDiscover: saw BLE device \(name) (\(uuid)) (looking for \(spectrometerName))")
            if name == spectrometerName
            {
                print("  found \(name)")
                peripheral.delegate = self
                let rec = SpectrometerSeenRec(peripheral, RSSI: RSSI)
                seenSpectrometers[uuid] = rec
                viewDelegate?.reloadTableData()
            }
        }
    }
    
    /// STEP 7. called at successful device connection (pairing)
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)
    {
        print("didConnect to \(String(describing: peripheral.name))")
        
        if let rec = seenSpectrometers[peripheral.identifier.uuidString]
        {
            // Keep scanning whenever we're on the pairing screen
            // keepScanning = false
            
            // does this need to be in an async dispatch closure? see step 7,
            // https://www.appcoda.com/core-bluetooth/
            viewDelegate?.enableDisconnect(true)
            
            spectrometer.setPeripheral(rec.peripheral)
            centralManager.stopScan()
            
            // now that we've discovered and connected to the DEVICE,
            // see what SERVICES it has on offer
            print("BLEController.didConnect: discovering peripheral services (looking for \(sigPrimaryService))")
            peripheral.discoverServices([sigPrimaryService])
        }
        else
        {
            print("ERROR: successfully connected to non-seen spectrometer?")
            centralManager.cancelPeripheralConnection(peripheral)
            doDisconnect()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?)
    {
        doDisconnect()
    }

    func doDisconnect()
    {
        spectrometer.disconnect()
        
        // in 1sec, redraw table (time for disconnect to complete)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(1000))
        {
            self.viewDelegate?.reloadTableData()
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    // CBPeripheralDelegate
    ////////////////////////////////////////////////////////////////////////////
    
    /// STEP 8: discovered services on a connected peripheral
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?)
    {
        for service in peripheral.services!
        {
            print("didDiscoverServices: peripheral \(peripheral) had service \(service)")
            if service.uuid == sigPrimaryService
            {
                print("BLEController.didDiscoverServices: found primary SiG service \(service)")
                
                
                let maxLenACK  = peripheral.maximumWriteValueLength(for: CBCharacteristicWriteType.withResponse)
                let maxLenNACK = peripheral.maximumWriteValueLength(for: CBCharacteristicWriteType.withoutResponse)
                print("didDiscoverCharacteristicsForService[metrics]: maximumWriteValueLength(withResponse   ) = \(maxLenACK)")
                print("didDiscoverCharacteristicsForService[metrics]: maximumWriteValueLength(withoutResponse) = \(maxLenNACK)")

                // STEP 9: discover characteristics
                print("didDiscoverServices: querying characteristics")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    /// STEP 10: characteristic discovery
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?)
    {
        for characteristic in service.characteristics!
        {
            var found = false
            for (name, cbuuid) in uuidByName
            {
                if cbuuid == characteristic.uuid
                {
                    spectrometer.registerCharacteristic(name, characteristic)
                    found = true
                    break
                }
            }
            if !found
            {
                print("ERROR: unrecognized characteristic \(characteristic)")
            }
        }
    }
    
    /// Whenever our iOS app (typically the Spectrometer class) tries to read a
    /// characteristic, the response comes back (asynchronously) through this callback,
    /// so forward it on.
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
    {
        spectrometer?.receiveValue(characteristic: characteristic)
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // Persistence
    ////////////////////////////////////////////////////////////////////////////

    func loadAppSettings() -> AppSettings?
    {
        print("loadAppSettings: start")
        let url = AppSettings.archiveURL
        
        do
        {
            print("loadAppSettings: reading from \(url)")
            let data = try Data(contentsOf: url)
            if let settings = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [AppSettings]
            {
                print("loadAppSettings: loaded \(settings.count) settings")
                return settings.first
            }
        }
        catch
        {
        }
        print("loadAppSettings: failed")
        return AppSettings()
    }

    func persist(uuid: String, serialNumber : String)
    {
        print("Persisting \(serialNumber) <-- \(uuid)")
        appSettings!.uuidToSerial[uuid] = serialNumber
        appSettings!.lastUUID = uuid
        saveAppSettings()
    }

    func saveAppSettings()
    {
        let url = AppSettings.archiveURL
        if appSettings?.uuidToSerial.count == 0
        {
            print("saveAppSettings: nothing to store")
            return
        }

        do
        {
            print("saveAppSettings: writing to \(url)")
            let data = try NSKeyedArchiver.archivedData(withRootObject: appSettings as Any, requiringSecureCoding: false)
            try data.write(to: url)
            print("saveAppSettings: succeeded?")
        }
        catch
        {
            print("saveAppSettings: failed")
        }
    }
}
