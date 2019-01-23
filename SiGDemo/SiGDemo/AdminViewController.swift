//
//  AdminViewController.swift
//  SiGDemo
//
//  Created by Mark Zieg on 12/27/18.
//  Copyright © 2018 Wasatch Photonics. All rights reserved.
//

import Foundation
import UIKit

class AdminViewController : UIViewController
{
    var bleController : BLEController!
    
    @IBOutlet weak var labelVersion: UILabel!
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        labelVersion.text = String("version \(AppSettings.version)")
    }
    
    /// Pass bleController to the active view, so that it never goes
    /// out-of-scope and is destroyed.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if let settingsViewController = segue.destination as? SettingsViewController
        {
            print("AdminViewController: passing BLEController to SettingsViewController")
            settingsViewController.bleController = bleController
        }
    }
}
