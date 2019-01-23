//
//  ScopeViewController.swift
//  SiGDemo
//
//  Created by Mark Zieg on 11/12/18.
//  Copyright © 2018 Wasatch Photonics. All rights reserved.
//

import UIKit
import SwiftChart

// act as a TextField delegate to auto-clear numeric fields on edit
// act as a ChartDelegate to control touch behaviors
// act as a BatteryViewDelegate to display battery status
class ScopeViewController:
    UIViewController,
    UITextFieldDelegate,
    ChartDelegate,
    SpectrumDelegate,
    BatteryDelegate
{
    ////////////////////////////////////////////////////////////////////////////
    // Data types
    ////////////////////////////////////////////////////////////////////////////

    // used by Chart
    typealias Point = (x: Double, y: Double)

    ////////////////////////////////////////////////////////////////////////////
    // Outlets
    ////////////////////////////////////////////////////////////////////////////

    @IBOutlet var myChart: Chart!
    @IBOutlet var labelLaserFiring: UILabel!
    @IBOutlet var switchLaserEnable: UISwitch!
    @IBOutlet var buttonSample: UIButton!
    @IBOutlet var buttonSave: UIButton!
    @IBOutlet var labelCursor: UITextField!
    @IBOutlet weak var imageBattery: UIImageView!
    @IBOutlet weak var labelSimulation: UILabel!
    @IBOutlet weak var labelCursorUnit: UILabel!
    
    // We want these TextFields to get a "Done" button on keypad
    @IBOutlet var textFieldIntegrationTimeMS: UITextField!
    {
        didSet
        {
            textFieldIntegrationTimeMS?.addDoneToolbar(
                onDone: (target: self, action: #selector(textFieldDone)))
        }
    }
    
    @IBOutlet var textFieldGain: UITextField!
    {
        didSet
        {
            textFieldGain?.addDoneToolbar(
                onDone: (target: self, action: #selector(textFieldDone)))
            if let spec = spectrometer
            {
                textFieldGain.text = String(spec.gain)
            }
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // attributes
    ////////////////////////////////////////////////////////////////////////////

    // this is passed-in by the master ViewController
    var bleController : BLEController!
    
    var spectrometer : Spectrometer!
    
    // TODO: this needs to be mastered in Spectrometer if it's to be persisted
    // across visits to the Scope view
    var lastSpectrum : [Double]?

    ////////////////////////////////////////////////////////////////////////////
    // lifecycle
    ////////////////////////////////////////////////////////////////////////////

    override func viewDidLoad()
    {
        super.viewDidLoad()

        // Redirect TextField delegates to this class.  That's because we want
        // these TextFields to auto-clear when the user starts typing a value,
        // since the user typically can't see the field when typing.
        textFieldIntegrationTimeMS.delegate = self
        textFieldGain.delegate = self
        
        // redirect Chart delegates to this class to handle touch events
        myChart.delegate = self
        
        // put empty series on graph, so subsequent calls can replace it
        let series = ChartSeries(data: [(x:0, y:0)])
        myChart.add(series)
        
        imageBattery.image = UIImage(named: "Battery-Empty")
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)

        // convenience handle to Spectrometer
        spectrometer = bleController.spectrometer
        if spectrometer == nil
        {
            fatalError("ScopeViewController: spectrometer should never be nil!")
        }
        
        // while this view is visible, it should receive spectra and battery updates
        spectrometer.spectrumDelegate = self
        spectrometer.battery.delegate = self
        spectrometer.requestBatteryStatus()
        
        if spectrometer != nil && spectrometer!.initialized
        {
            labelSimulation.isHidden = true
        }

        // initialize outlets
        initFromSpectrometer()
        
        if lastSpectrum != nil
        {
            processSpectrum(spectrum: lastSpectrum!, done: true)
            buttonSave.isEnabled = true
        }
        else
        {
            buttonSave.isEnabled = false
        }
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        // make sure laser is off
        spectrometer.setLaserEnabled(false)
        
        // we'll no longer be around to accept spectra
        spectrometer.spectrumDelegate = nil
    }
    
    func initFromSpectrometer()
    {
        textFieldIntegrationTimeMS.text = String(format: "%d", spectrometer.integrationTimeMS)
        textFieldGain.text = String(format: "%d", spectrometer.gain)
        switchLaserEnable.isOn = spectrometer.laserEnabled
        labelLaserFiring.isHidden = !switchLaserEnable.isOn
    }

    ////////////////////////////////////////////////////////////////////////////
    // Methods
    ////////////////////////////////////////////////////////////////////////////

    // This is the callback for the "Done" button we added to the numeric/decimal
    // keypads.  There's nothing per-field in it, so it can be shared across all
    // textfields.
    @objc func textFieldDone() -> ()
    {
        self.resignFirstResponder()
        view.endEditing(true)
    }
    
    @IBAction func integrationTimeMSChanged(_ sender: UITextField)
    {
        var valid = false
        if let ms: Int = Int(textFieldIntegrationTimeMS.text!)
        {
            // I don't know if these are realistic
            if (spectrometer.eeprom.min_integration_time_ms <= ms &&
                ms <= spectrometer.eeprom.max_integration_time_ms)
            {
                spectrometer.setIntegrationTime(ms: ms)
                valid = true
            }
        }

        if (!valid)
        {
            print("ERROR: ignoring invalid integration time \(String(describing: textFieldIntegrationTimeMS))")
            textFieldIntegrationTimeMS.text = String(spectrometer.integrationTimeMS)
        }
    }
    
    @IBAction func gainChanged(_ sender: UITextField)
    {
        var valid = false
        if let n: Int = Int(textFieldGain.text!)
        {
            if (0 <= n && n <= 39)
            {
                spectrometer.setGain(n)
                valid = true
            }
        }
        
        if (!valid)
        {
            print("ERROR: ignoring invalid gain \(String(describing: textFieldGain))")
            textFieldGain.text = String(spectrometer.gain)
        }

    }
    
    @IBAction func laserEnableChanged(_ sender: UISwitch)
    {
        spectrometer.setLaserEnabled(switchLaserEnable.isOn)
        self.labelLaserFiring.isHidden = !(spectrometer.laserEnabled)
    }
    

    // Request the generation and reading of a new spectrum via multiple BLE
    // messages.  When finished, Spectrometer will call updateGraph().
    @IBAction func sampleClicked(_ sender: UIButton)
    {
        spectrometer.requestSpectrum()
    }
    
    // This is where we should send the spectrum to the server
    // https://stackoverflow.com/a/41082877
    // Cloud stuff should probably be encapsulated to a class
    @IBAction func saveClicked(_ sender: UIButton)
    {
        ////////////////////////////////////////////////////////////////////////
        // Instantiate URLRequest
        ////////////////////////////////////////////////////////////////////////
        
        let url = URL(string: "https://mco.wasatchphotonics.com/cgi-bin/save-spectrum.py")!

        let session = URLSession.shared
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        ////////////////////////////////////////////////////////////////////////
        // Populate request data
        ////////////////////////////////////////////////////////////////////////

        // TODO: create a "Measurement" class that can be sent from Spectrometer
        // to ScopeViewController (and Matching, etc) which encapsulates laser
        // state, wavecal etc
        
        let metadata = [
            "serialNumber": spectrometer.eeprom.serial_number,
            "model": spectrometer.eeprom.model,
            "integrationTimeMS": spectrometer.integrationTimeMS,
            "gain": spectrometer.gain,
            "deviceName": UIDevice.current.name,
            "deviceModel": UIDevice.current.model,
            "deviceSystemVersion": UIDevice.current.systemVersion,
            "deviceLocalizedModel": UIDevice.current.localizedModel,
            "deviceSystemName": UIDevice.current.systemName,
            "deviceModelInfo": PhoneInfo.getModelName()
        ] as [String : Any]
        
        let spectrum = [
            "wavelengths": spectrometer.wavelengths,
            "wavenumbers": spectrometer.wavenumbers,
            "raw": lastSpectrum,
            "dark": nil,
            "reference": nil,
            "processed": lastSpectrum
        ]
        
        let measurement = [
            "spectrum": spectrum,
            "metadata": metadata
        ] as [String : Any]
        
        let requestData = [
            "measurement": measurement
        ]
        
        do
        {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestData, options: .prettyPrinted)
        }
        catch let error
        {
            print ("Scope.save: error serializing parameters: \(error.localizedDescription)")
            return
        }

        ////////////////////////////////////////////////////////////////////////
        // Asynchronously execute request
        ////////////////////////////////////////////////////////////////////////

        print("Scope.save: generating dataTask")
        let task = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
            
            guard error == nil else {
                print("Scope.save: task error was \(String(describing: error))")
                return
            }

            guard let data = data else {
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                    print("Scope.save: response = \(json)")
                    // handle json...
                }
            } catch let error {
                print("Scope.save: response parse error: \(error.localizedDescription)")
            }
        })
        task.resume()
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // TextFieldDelegate
    ////////////////////////////////////////////////////////////////////////////

    // Because phone screens are so cramped, the virtual keypad is so big,
    // and we've placed fields down at the bottom of the screen (below the
    // chart), the user generally can't see the textfield while editing it.
    // We could fix this by making it a scrollable area or something, but for
    // now just auto-clear any textfields on edit which use this class as
    // their delegate.
    func textFieldDidBeginEditing(_ textField: UITextField)
    {
        textField.text = ""
    }

    ////////////////////////////////////////////////////////////////////////////
    // SpectrumDelegate
    ////////////////////////////////////////////////////////////////////////////

    // Spectrometer has finished reading a new spectrum, and passed it here for
    // graphing.
    func processSpectrum(spectrum: [Double], done: Bool)
    {
        ////////////////////////////////////////////////////////////////////////
        // Generate X-Axis
        ////////////////////////////////////////////////////////////////////////

        let pixels = spectrum.count
        var xAxis : [Double] = []
        
        if spectrometer.xAxis.type == XAxis.Types.WAVENUMBER && spectrometer.wavenumbers != nil
        {
            xAxis = spectrometer.wavenumbers!
            labelCursorUnit?.text = "Cursor (cm⁻¹)"
        }
        else if spectrometer.xAxis.type == XAxis.Types.WAVELENGTH && spectrometer.wavelengths != nil
        {
            xAxis = spectrometer.wavelengths!
            labelCursorUnit?.text = "Cursor (nm)"
        }
        else
        {
            // default to pixel axis
            xAxis = [Double](repeating: 0.0, count: pixels)
            for i in 0 ..< pixels
            {
                xAxis[i] = Double(i)
            }
            labelCursorUnit?.text = "Cursor (px)"
        }
        
        ////////////////////////////////////////////////////////////////////////
        // Store for later saving
        ////////////////////////////////////////////////////////////////////////
        
        if done
        {
            lastSpectrum = spectrum
            buttonSave.isEnabled = true
        }

        ////////////////////////////////////////////////////////////////////////
        // Graph
        ////////////////////////////////////////////////////////////////////////

        var data: [Point] = [Point]()
        for i in 0 ..< pixels
        {
            let x = xAxis[i]
            let y = spectrum[i]

            data.append(Point(x, y))
        }
        
        myChart.removeSeriesAt(0)
        let series = ChartSeries(data: data)
        myChart.add(series)
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // ChartDelegate
    ////////////////////////////////////////////////////////////////////////////

    func didTouchChart(_ chart: Chart, indexes: [Int?], x: Double, left: CGFloat)
    {
        // for (seriesIndex, dataIndex) in indexes.enumerated() {
        for (_, dataIndex) in indexes.enumerated()
        {
            if dataIndex != nil
            {
                // let y = chart.valueForSeries(seriesIndex, atIndex: dataIndex)
                labelCursor.text = String(format:"%.2f", x)
            }
        }
    }
    
    func didFinishTouchingChart(_ chart: Chart) { }
    
    func didEndTouchingChart(_ chart: Chart) { }
    
    ////////////////////////////////////////////////////////////////////////////
    // BatteryDelegate
    ////////////////////////////////////////////////////////////////////////////

    func updateBattery(image: UIImage, sender: Battery)
    {
        imageBattery.image = image
    }
    
    func updateBattery(chargeLevel: Double, charging: Bool)
    {
        // ignore (Scope shows battery icon)
    }
}
