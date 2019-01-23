/*
 This file is responsible for everything dealing with Bluetooth pairing
 and discovery.
 
 Follow the numbered "STEP" hints in the comments to trace workflow.
 
 Note that currently we are scanning for ANY device with the advertisedName
 "WP-SiG" — we are not filtering by UUID.
 
 TODO: persist the UUID of the "last" spectrometer with which we paired,
 and auto-connect to that if within range (would require scanning to
 start automatically).
*/

import UIKit
import CoreBluetooth // note "CB" prefix in class names

// This is a single row in our UI table of "seen" spectrometers.
// Todo: add customizable images by model
class BLETableViewCell: UITableViewCell
{
    @IBOutlet var labelUUID: UILabel!
    @IBOutlet var labelRSSI: UILabel!
}

// This class implements the "Pair" storyboard, functioning as a
// CoreBluetooth Delegate for both CentralManager and Peripherals,
// as well as the TableView cells used to list discovered spectrometers.
class BLEViewController:
    UIViewController,
    UITableViewDataSource,
    UITableViewDelegate,
    BLEControllerViewDelegate,
    EEPROMLoadDelegate
{
    ////////////////////////////////////////////////////////////////////////////
    // outlets
    ////////////////////////////////////////////////////////////////////////////
    
    @IBOutlet var buttonScan: UIButton!
    @IBOutlet var buttonDisconnect: UIButton!
    @IBOutlet var seenSpectrometerTable: UITableView!
    
    ////////////////////////////////////////////////////////////////////////////
    // properties
    ////////////////////////////////////////////////////////////////////////////
    
    // These are passed-in by the master ViewController.  The Spectrometer has
    // to be at application scope so that other views (like Scope) can access
    // it, and the CBCentralManager needs (I think) to be at application scope
    // to maintain live control of its CBPeripheral.  This begs the question
    // who becomes the CBCentralManagerDelegate and CBPeripheralDelegate when
    // the BLEViewController is closed.
    
    var bleController: BLEController!
    var circularProgressBar: CircularProgressBar!

    ////////////////////////////////////////////////////////////////////////////
    // lifecycle
    ////////////////////////////////////////////////////////////////////////////
    
    // STEP 0. Create the CoreBluetooth CentralManager, point delegates to self.
    override func viewDidLoad()
    {
        super.viewDidLoad()

        seenSpectrometerTable.delegate = self
        seenSpectrometerTable.dataSource = self
        
        circularProgressBar = CircularProgressBar(self.view)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        bleController.viewDelegate = self
        bleController.spectrometer.eepromLoadDelegate = self
        bleController.keepScanning = true
        buttonDisconnect.isEnabled = bleController.spectrometer.initialized
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        bleController.keepScanning = false
        bleController.viewDelegate = nil
        bleController.spectrometer.eepromLoadDelegate = nil
    }

    ////////////////////////////////////////////////////////////////////////////
    // outlet callbacks
    ////////////////////////////////////////////////////////////////////////////
    
    @IBAction func scanClicked(_ sender: Any)
    {
        bleController.keepScanning = true
        bleController.resumeScan()
    }

    @IBAction func disconnectClicked(_ sender: UIButton)
    {
        bleController.spectrometer.disconnect()
        buttonDisconnect.isEnabled = false
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // BLEControllerViewDelegate
    ////////////////////////////////////////////////////////////////////////////

    /// BUG: this isn't forcing redraw (and decolorization) of previously-connected
    /// device following disconnect
    func reloadTableData()
    {
        seenSpectrometerTable.setNeedsDisplay()
        seenSpectrometerTable.reloadData()
    }
    
    func enableDisconnect(_ flag: Bool)
    {
        buttonDisconnect.isEnabled = flag
    }
    
    func showAlertMessage(_ message : String)
    {
        let alertController = UIAlertController(
            title: "Central Manager State",
            message: message,
            preferredStyle: UIAlertController.Style.alert)
        let okAction = UIAlertAction(
            title: "OK",
            style: UIAlertAction.Style.cancel,
            handler: nil)
        alertController.addAction(okAction)
        self.show(alertController, sender: self)
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // EEPROMLoadDelegate
    ////////////////////////////////////////////////////////////////////////////

    func pairingStatus(started: Bool)
    {
        circularProgressBar.display()
    }

    func pairingStatus(percentage: Float)
    {
        circularProgressBar.updatePercentage(percentage)
    }
    
    func pairingStatus(complete: Bool)
    {
        circularProgressBar.hide()
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // UITableViewDataSource
    ////////////////////////////////////////////////////////////////////////////

    // later if we want to get clever, we could section the table by model
    // (UV-VIS, VIS-NIR, 785, 830, 1064 etc)
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    // STEP 3. This is how the TableView knows how many spectrometers we've seen, thus
    // how many rows to populate in the table.
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return bleController.seenSpectrometers.count
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        print("tableView: preparing to DISPLAY cell for indexPath \(indexPath)")
    }
    
    // STEP 4. This is how the table of "seen" SiG devices is populated.  For each row
    // within numberOfRowsInSection, the TableView will call this method to populate
    // that particular row (cell).
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cellIdentifier = "BLETableViewCell"
        
        guard
            let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? BLETableViewCell
        else
        {
            print("Can't cast reusable cell as \(cellIdentifier)")
            return UITableViewCell()
        }
        
        if let rec = bleController.getOrderedSpectrometer(index: indexPath.row)
        {
            // if the UUID string has already been associated with a serialNumber,
            // display that instead
            var label = rec.peripheral.identifier.uuidString
            if let serialNumber = bleController.appSettings?.uuidToSerial[label]
            {
                label = serialNumber
            }
            
            cell.labelUUID.text = label
            cell.labelRSSI.text = String(format:"%.2f", rec.lastRSSI)
            cell.backgroundColor = UIColor.clear
            
            if bleController.spectrometer.initialized
            {
                if rec.peripheral.identifier.uuidString == bleController.spectrometer.peripheral?.identifier.uuidString
                {
                    print("Displaying selected peripheral")
                    cell.backgroundColor = cicelyLightBlue
                }
                else
                {
                    print("not connected unit")
                }
            }
            else
            {
                print("no connected unit")
            }
        }
        return cell
    }
    
    // STEP 5. The user has tapped a row in our list of displayed "seen" devices, so
    // prompt the user to pair with the device.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        print("tableView: SELECTED cell at indexPath \(indexPath)")
        
        if let rec = bleController.getOrderedSpectrometer(index: indexPath.row)
        {
            let alert = UIAlertController(title: "Pair with SiG device?", message: "Connect with spectrometer to take remote measurements.", preferredStyle: .alert)
            
            // call our pair() function if the user clicks "Yes"
            alert.addAction(UIAlertAction(
                title: "Yes",
                style: .default,
                handler: { (action:UIAlertAction!) in self.bleController.pair(rec.peripheral.identifier.uuidString) }))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
            
            self.present(alert, animated: true)
        }
    }
}
