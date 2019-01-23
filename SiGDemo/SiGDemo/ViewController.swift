//
//  ViewController.swift
//  SiGDemo
//
//  Created by Mark Zieg on 11/12/18.
//  Copyright © 2018 Wasatch Photonics. All rights reserved.
//

import UIKit

/// This is the ViewController for the Main Menu.
class ViewController:
    UIViewController,
    BatteryDelegate
{
    /// This is as close as we have to a master "session" object.
    /// It's instantiated and owned here, and passed down into
    /// other UIViewControllers so that it stays active and isn't
    /// garbage-collected.
    var bleController : BLEController!

    @IBOutlet weak var batteryLabel: UILabel!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        bleController = BLEController()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)

        print("ViewController will appear")
        batteryLabel.text = ""
        if let battery = bleController.spectrometer?.battery
        {
            print("setting battery delegate to ViewController and requesting update")
            battery.delegate = self
            bleController.spectrometer?.requestBatteryStatus()
        }
    }

    /// Pass bleController to the active view, so that it never goes
    /// out-of-scope and is destroyed.
    ///
    /// Should we just pass out references to all ViewControllers once, at load?
    ///
    /// Could also make all our ViewControllers inherit from a custom base VC
    /// with a BLEController reference.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if let vc = segue.destination as? BLEViewController
        {
            vc.bleController = bleController
        }
        else if let vc = segue.destination as? ScopeViewController
        {
            vc.bleController = bleController
        }
        else if let vc = segue.destination as? AdminViewController
        {
            vc.bleController = bleController
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // BatteryDelegate
    ////////////////////////////////////////////////////////////////////////////
    
    func updateBattery(image: UIImage, sender: Battery)
    {
        // ignore
    }
    
    func updateBattery(chargeLevel: Double, charging: Bool)
    {
        print("ViewController updating battery level")
        batteryLabel?.text = String(format: "Battery: %d%%%@", Int(chargeLevel), charging ? " (charging)" : "")
    }
}
