//
//  EEPROMViewController.swift
//  SiGDemo
//
//  Created by Mark Zieg on 12/24/18.
//  Copyright © 2018 Wasatch Photonics. All rights reserved.
//

import Foundation
import UIKit

class EEPROMTableViewCell: UITableViewCell
{
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var value: UILabel!
}

class EEPROMViewController:
    UIViewController,
    UITableViewDataSource,
    UITableViewDelegate
{
    var bleController : BLEController!
    var spectrometer : Spectrometer!
    var eeprom : EEPROM!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if bleController == nil
        {
            fatalError("EEPROMViewController requires BLEController")
        }
        
        // convenience handle to Spectrometer
        spectrometer = bleController.spectrometer
        if spectrometer == nil
        {
            fatalError("EEPROMViewController: spectrometer should never be nil!")
        }
        
        // while this form is visible, it should receive new spectra
        eeprom = spectrometer.eeprom
    }
    
    /// EEPROM pages 0-5...grow later for FPGACompilationOptions etc
    func numberOfSections(in tableView: UITableView) -> Int {
        return EEPROM.PAGE_COUNT
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        if let keys = eeprom?.displayKeys[section]
        {
            return keys.count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        return String(format: "EEPROM Page %d", section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let page = indexPath.section
        let row = indexPath.row
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: "EEPROMTableViewCell", for: indexPath) as? EEPROMTableViewCell
        {
            if let fieldsThisPage = eeprom?.displayKeys[page]
            {
                let field = fieldsThisPage[row]
                if let fieldValues = eeprom?.displayable[page]
                {
                    cell.name.text = field
                    if let value = fieldValues[field]
                    {
                        let unwrapped : String = value
                        print("EEPROM field \(field) = \(unwrapped)")
                        cell.value.text = unwrapped
                    }
                    else
                    {
                        cell.value.text = "null"
                    }
                    return cell
                }
            }
        }
        print("ERROR: can't dequeue EEPROMTableViewCell")
        return UITableViewCell()
    }
}
