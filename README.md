![Scope Mode](https://github.com/WasatchPhotonics/Wasatch.Swift/raw/master/screenshots/SiGDemo-scope.png)

# Overview

A simple iPhone app controlling a Wasatch Photonics SiG-785 Raman spectrometer.

# Building

# Dependencies

- XCode 10.1 (Swift 4.2.1)
- [jazzy](https://github.com/realm/jazzy) (render docs)

## CocoaPods

On MacOS, install CocoaPod package manager using HomeBrew:

    $ brew install cocoapods

To install pods used by SiGDemo, use:

    $ git clone git@github.com:WasatchPhotonics/Wasatch.Swift.git
    $ cd Wasatch.Swift
    $ pod install

The current version of SwiftCharts seems to have a single line that needed 
changed...something about a bevel.  Xcode knew how to fix it, but I had to
use "Manage Schemes" to expose the SwiftCharts scheme for editing in Xcode,
then a ⌘-B to build the framework and find the problematic line.

(Note that Jazzy installation seems to prefer _gem_ over _brew_...YMMV.)

## Charting

- [SwiftChart](https://github.com/gpbl/SwiftChart)

XCode note: make following patch in Chart.swift:

    < lineLayer.lineJoin = kCALineJoinBevel
    > lineLayer.lineJoin = CAShapeLayerLineJoin.bevel

# References

I'm new to Xcode and Swift, so leaving some breadcrumbs.  These 
were all useful in learning enough Swift to stand-up the demo:

- [Bucky Tutorials](https://www.youtube.com/playlist?list=PL6gx4Cwl9DGDgp7nGSUnnXihbTLFZJ79B)
- [Stanford Course](https://www.youtube.com/watch?v=71pyOB4TPRE)
- [Stack Views](https://www.youtube.com/watch?v=-haK6v6YiU8)
- [Zero to BLE](https://www.cloudcity.io/blog/2015/06/11/zero-to-ble-on-ios-part-one/)
- [Core Bluetooth](https://www.appcoda.com/core-bluetooth/)
- [Bluetooth SIG membership](https://www.bluetooth.com/develop-with-bluetooth/join)
- [DataControllers](https://stackoverflow.com/a/42834297) and [State](https://code.tutsplus.com/tutorials/the-right-way-to-share-state-between-swift-view-controllers--cms-28474)
- [Progress Rings](https://www.letsbuildthatapp.com/course_video?id=2342)

This is the BLE chip used for the initial SiG-BLE design:

- [CC2640R2F](http://www.ti.com/product/CC2640R2F/technicaldocuments)
- [SimpleLink Academy](http://dev.ti.com/tirex/#/?link=Software%2FSimpleLink%20CC2640R2%20SDK%2FSimpleLink%20Academy%2FOverview)
- [TI BLE-Wiki](http://www.ti.com/ble-wiki)
- [Quick Start](http://software-dl.ti.com/simplelink/esd/simplelink_cc2640r2_sdk/1.50.00.58/exports/docs/Documentation_Overview.html)

# Testing

These iPhone apps were also used as 3rd-party confirmation that BLE services were
discoverable, and that characteristics could be read and written:

- [LightBlue Explorer](https://itunes.apple.com/us/app/lightblue-explorer/id557428110?mt=8)
- [BLE Scanner](https://itunes.apple.com/us/app/ble-scanner-4-0/id1221763603?mt=8)

# Rendered Documentation

If you have `jazzy` installed, just type this:

    $ make docs

# Backlog

## Version 1.0

- support in-app dark correction
- add "desc" note field
- add fields to specify URL for cloud upload
- add SW "Raman" mode where laser is enabled prior to ACQUIRE, and disabled
  as soon as the first spectrum packet is received
- refresh BLE table on disconnect

## Version 2.0

- support compound matching / identification
- make BLE screen more like Settings
    - two sections, "Connected" and "Available"
    - add little blue checkmark by connected device
    - change RSSI percentage to WiFi range icon

## Version 3.0

- Apple Watch (no real point until compound ID working)

# Version History

- 2019-01-23 1.1.0
    - moved to GitHub / MIT license
- 2019-01-21 1.0.2
    - added responseRequired BLE setting (default off)
- 2019-01-21 1.0.1
    - added timing metrics
- 2019-01-21 1.0.0
    - added logical version number on Admin screen
    - added AppSettings to persist uuid -> SN mapping
- 2019-01-08 0.7.15
    - added iPhone device info to metadata
    - tweaks for iPhone 8 Plus form-factor
- 2019-01-07 0.7.14
    - added serialNumber and model to metadata
    - add serialNumber to saved filenames
    - wait one integration time before attempting to read newly commanded spectrum
    - ignore (extrapolate) first/last 4 pixels on SiG spectra
    - always disable laser on leaving scope view
    - expanded Pair row somewhat to fully show UUID
    - added aggregate-daily.py
- 2019-01-03 0.7.13
    - enabled selectable x-axis unit in Scope mode
- 2019-01-03 0.7.12
    - save Measurement in JSON
    - add metadata and optional fields to CSV
    - battery delegates are updated on ViewController appearance
    - highlight connected unit on re-visiting Pair screen
    - EEPROM strings cleaned up
- 2019-01-02 0.7.11
    - updated logos
- 2018-12-27 0.7.10
    - X-Axis UIPicker works (graph still hardcoded to pixels)
    - initial values for integration time, gain set correctly
    - battery works better
    - added "Simulation" banner (breaks laser)
    - fair bit of application testing
- 2018-12-27 0.7.9
    - added partial spectral display for Scope
    - added circular progress bar for EEPROM load
- 2018-12-27 0.7.8
    - tested integration time, gain, laser enable
- 2018-12-27 0.7.7
    - split-out EEPROMViewController from SettingsViewController
- 2018-12-26 0.7.6
    - switch spectra to little-endian
- 2018-12-26 0.7.5
    - restore EEPROM logging at connection
- 2018-12-26 0.7.4
    - changed HTTP POST to HTTPS
- 2018-12-26 0.7.3
    - added SiG battery icon
- 2018-12-24 0.7.2
    - populated EEPROM fields in Settings page (untested)
    - display battery charge level
- 2018-12-19 0.7.1
    - EEPROM actually works
- 2018-12-19 0.7.0
    - switched to prototype BLE ICD
    - added EEPROM
- 2018-11-20 0.6.0
    - save spectra to HTTP POST
- 2018-11-20 0.5.0
    - first spectrum read from live spectrometer
- 2018-11-12 0.1.0
    - initial storyboard stubs

![Pairing](https://github.com/WasatchPhotonics/Wasatch.Swift/raw/master/screenshots/SiGDemo-pair.png)
