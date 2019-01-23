//
//  SettingsViewController.swift
//  SiGDemo
//
//  Created by Mark Zieg on 12/27/18.
//  Copyright © 2018 Wasatch Photonics. All rights reserved.
//

import Foundation
import UIKit

class SettingsViewController:
    UIViewController,
    UITableViewDataSource,
    UITableViewDelegate,
    UIPickerViewDelegate,
    UIPickerViewDataSource,
    UITextFieldDelegate
{
    var bleController : BLEController!
    var spectrometer : Spectrometer!
    
    @IBOutlet weak var settingsTable: UITableView!
    
    var axisPicker : UIPickerView!
    var activeTextField : UITextField!

    ////////////////////////////////////////////////////////////////////////////
    // Lifecycle
    ////////////////////////////////////////////////////////////////////////////

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        settingsTable.delegate = self
        settingsTable.dataSource = self
    }
    
    func configurePicker(_ textField : UITextField)
    {
        // UIPickerView
        axisPicker = UIPickerView(frame:CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 216))
        axisPicker.delegate = self
        axisPicker.dataSource = self
        axisPicker.backgroundColor = UIColor.white
        textField.inputView = self.axisPicker
        
        // ToolBar
        let toolBar = UIToolbar()
        toolBar.barStyle = .default
        toolBar.isTranslucent = true
        toolBar.tintColor = UIColor(red: 92/255, green: 216/255, blue: 255/255, alpha: 1)
        toolBar.sizeToFit()
        
        // Adding Button ToolBar
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(self.doneClick))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.cancelClick))
        toolBar.setItems([cancelButton, spaceButton, doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        textField.inputAccessoryView = toolBar
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        spectrometer = bleController.spectrometer
    }

    ////////////////////////////////////////////////////////////////////////////
    // UITableViewDelegate & UITableViewDataSource
    ////////////////////////////////////////////////////////////////////////////

    // could just roll EEPROM into the bottom of this...?
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        print("SettingsViewController: preparing to DISPLAY cell for indexPath \(indexPath)")
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let row = indexPath.row
        print("SettingsViewController: generating cell for row \(row)")
        if row == 0
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCellTextfield", for: indexPath)
            if let textfieldCell = cell as? SettingsCellTextfield
            {
                textfieldCell.label?.text = "X-Axis"
                if let xAxis = bleController?.spectrometer?.xAxis
                {
                    textfieldCell.value?.text = xAxis.description
                }
                // textfieldCell.value.inputView = axisPicker
                // textfieldCell.value.inputAccessoryView = toolBar
                textfieldCell.value.delegate = self
                return cell
            }
        }
        else if row == 1
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCellDetail", for: indexPath)
            cell.accessoryType = .disclosureIndicator
            cell.textLabel?.text = "EEPROM"
            return cell
        }
        else if row == 2
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCellSwitch", for: indexPath)
            if let cellSwitch = cell as? SettingsCellSwitch
            {
                cellSwitch.name?.text = "ACK Required"
                cellSwitch.value?.isOn = bleController.requireResponse
                cellSwitch.value?.addTarget(self, action: #selector(self.ackChanged(_:)), for: .valueChanged)
                return cell
            }
        }
        
        print("unimplemented Settings row \(row)")
        return tableView.dequeueReusableCell(withIdentifier: "settingsCellDetail", for: indexPath)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        print("SettingsViewController: user SELECTED cell for indexPath \(indexPath)")
        let row = indexPath.row

        // X-axis
        if row == 0
        {
            // should have already been done by pickerView.didSelectRow
        }
        
        // EEPROM
        else if row == 1
        {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let viewController = storyboard.instantiateViewController(withIdentifier: "EEPROMViewController") as UIViewController
            if let eepromViewController = viewController as? EEPROMViewController
            {
                eepromViewController.bleController = bleController
                self.navigationController?.pushViewController(eepromViewController, animated: true)
            }
        }
        else if row == 2
        {
            print("Settings.didSelectRowAt: ack switch")
        }
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath)
    {
        print("SettingsViewController: user TAPPED ACCESSORY BUTTON for indexPath \(indexPath)")
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // UIPickerViewDelegate, UIPickerViewDataSource
    ////////////////////////////////////////////////////////////////////////////
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int
    {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int
    {
        return XAxis.labels.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return XAxis.labels[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int)
    {
        let label = XAxis.labels[row]
        spectrometer.xAxis.type = XAxis.labelToEnum(label)
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // UITextFieldDelegate
    ////////////////////////////////////////////////////////////////////////////

    func textFieldDidBeginEditing(_ textField: UITextField)
    {
        activeTextField = textField
        self.configurePicker(activeTextField)
    }
    
    @objc func doneClick()
    {
        let row = axisPicker.selectedRow(inComponent: 0)
        let label = XAxis.labels[row]
        activeTextField?.text = label
        
        activeTextField.resignFirstResponder()
    }
    
    @objc func cancelClick()
    {
        activeTextField.resignFirstResponder()
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // Misc callbacks
    ////////////////////////////////////////////////////////////////////////////

    @objc func ackChanged(_ sender : UISwitch!)
    {
        bleController.requireResponse = sender.isOn
        print("Settings.ackChanged: responseRequired = \(bleController.requireResponse)")
    }
}
