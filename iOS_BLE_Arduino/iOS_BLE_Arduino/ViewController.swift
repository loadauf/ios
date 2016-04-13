//
//  ViewController.swift
//  iOS_BLE_Arduino
//
//  Created by Hector Mejia on 3/5/16.
//  Copyright © 2016 Loro Studios. All rights reserved.
//

import UIKit
import CoreBluetooth
import CoreMotion
import CoreLocation
import GameKit

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, CLLocationManagerDelegate {
    
    // HECTOR ATTEMPT
    
    let staticThreshold = 0.008
    let slowWalkingThreshold = 0.01
    var accelerometerDataCount = 0.0
    var accelerometerDataInASecond = [Double]()
    var accelerometerDataInEuclidianNorm = 0.0
    var totalAcceleration = 0.0
    var pedestrianStatus: String!
    let roundingPrecision = 3
    var headingChecker = 0.0
    var arduinoCmd = [0,0,0]
    var headingTimer: NSTimer?
    var secondsCounter = 0
    // END OF HECTOR ATTEMPT
    
    
    
    
    
    // Instance variables
    let motionManager = CMMotionManager()
    var centralManager : CBCentralManager!
    var arduinoPeripheral : CBPeripheral!
    var positionCharacteristic: CBCharacteristic?
//    var lastPosition: UInt8 = 255
    var currentAcceleration: CMAcceleration?
    var lastPosition: Double = 255.0
    var timerTXDelay: NSTimer?
    var allowTX = true
    let samplingRate = 0.05
    @IBOutlet weak var slider: UISlider!
    var allowSending = false
    
    // MARK: - Managers
    var locationManager = CLLocationManager()
    var motionActivityManger = CMMotionActivityManager()
    
    
    // MARK: - Instance Variables
    var currentHeading: CLLocationDirection?
    var currentHeadingAccuracy: CLLocationDirection?
    var currentTrueHeading: CLLocationDirection?
    var currentMagneticHeading: CLLocationDirection?
    
    
    // IR Temp UUIDs
    let arduinoServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    let arduinoDataUUID   = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    let arduinoConfigUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    
    var titleLabel : UILabel!
    var statusLabel : UILabel!
    var tempLabel : UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        
        /*
        motionManager.startDeviceMotionUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: {(motionData: CMDeviceMotion?, error: NSError?) -> Void in
            
            
            if error != nil {
                print("\(error)")
                return
            }
            self.outputDeviceMotionData(motionData!)
            
        })
        
        motionManager.startGyroUpdatesToQueue(NSOperationQueue.mainQueue()) { (gyroData: CMGyroData?, error: NSError?) in
            if error != nil {
                print("\(error)")
                return
            }
            
            self.outputGyroData(gyroData!)
        }
         
         
 */
        
        
        headingTimer = NSTimer.scheduledTimerWithTimeInterval(0.15, target: self, selector: #selector(ViewController.didHeadingUpdate), userInfo: nil, repeats: true)
        
        
        startHeadingEvents()
        locationManager.delegate = self
        
        // Set up title label
        titleLabel = UILabel()
        titleLabel.text = "My SensorTag"
        titleLabel.font = UIFont(name: "HelveticaNeue-Bold", size: 20)
        titleLabel.sizeToFit()
        titleLabel.center = CGPoint(x: self.view.frame.midX, y: self.titleLabel.bounds.midY+28)
        self.view.addSubview(titleLabel)
        
        // Set up status label
        statusLabel = UILabel()
        statusLabel.textAlignment = NSTextAlignment.Center
        statusLabel.text = "Loading..."
        statusLabel.font = UIFont(name: "HelveticaNeue-Light", size: 12)
        statusLabel.sizeToFit()
        statusLabel.frame = CGRect(x: self.view.frame.origin.x, y: self.titleLabel.frame.maxY, width: self.view.frame.width, height: self.statusLabel.bounds.height)
        self.view.addSubview(statusLabel)
        
        // Set up temperature label
        tempLabel = UILabel()
        tempLabel.text = "000.000 "
        tempLabel.font = UIFont(name: "HelveticaNeue-Bold", size: 72)
        tempLabel.sizeToFit()
        tempLabel.center = self.view.center
        self.view.addSubview(tempLabel)
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        motionManager.accelerometerUpdateInterval = samplingRate
        motionManager.gyroUpdateInterval = samplingRate
        
        motionManager.startAccelerometerUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: {(accelerometerData: CMAccelerometerData?, error:NSError?) -> Void in
            
            
            if (error != nil)
            {
                print("\(error)")
                return
            }
            
//            self.outputAccelerationData(accelerometerData!)
            
            self.estimatePedestrianStatus(accelerometerData!.acceleration)
            
        })
        
    }
    
    func startHeadingEvents() {
        // Start location services to get the true heading.
        locationManager.distanceFilter = 10
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.startUpdatingLocation()
        
        // Start heading updates.
        if CLLocationManager.headingAvailable() {
            print("heading is available")
            locationManager.headingFilter = 5
            locationManager.startUpdatingHeading()
        }
        
    }
    
    @IBAction func sliderDidChange(sender: UISlider) {
        
//        sendPosition(UInt8( sender.value))
        
    }
    
    @IBAction func findButtonPressed(sender: AnyObject) {
        sendPosition(currentAcceleration!)
        
    }
    
    
    func outputAccelerationData(accelerometerData: CMAccelerometerData)
    {
        // Swift does not have string formating yet

//        currentAccelAngle = atan2(accelerometerData.acceleration.y, accelerometerData.acceleration.x) * (180/M_PI)

        currentAcceleration = accelerometerData.acceleration
        
//        print("Acceleration - x: \(accelerometerData.acceleration.x), y: \(accelerometerData.acceleration.y), z: \(accelerometerData.acceleration.z)")
        if allowSending {
//            sendPosition(accelerometerData.acceleration)
        }
    }
    
    
    
    
    
    
    // Check status of BLE hardware
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == CBCentralManagerState.PoweredOn {
            // Scan for peripherals if BLE is turned on
            central.scanForPeripheralsWithServices(nil, options: nil)
            self.statusLabel.text = "Searching for BLE Devices"
        }
        else {
            // Can have different conditions for all states if needed - print generic message for now
            print("Bluetooth switched off or not initialized")
        }
    }

    // Check out the discovered peripherals to find Sensor Tag
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        let deviceName = "Adafruit Bluefruit LE"
//        print(peripheral.name)
        let nameOfDeviceFound = (advertisementData as NSDictionary).objectForKey(CBAdvertisementDataLocalNameKey) as? NSString
        print("discovered:\t\(nameOfDeviceFound) : \(RSSI) : \(peripheral.identifier.UUIDString)")
//        print("\(peripheral.identifier)")
        if (nameOfDeviceFound == deviceName) {
            print("\n\nArduino Found\n\n")
            // Update Status Label
            self.statusLabel.text = "bluefruit Found"
            
            // Stop scanning
            //self.centralManager.stopScan()
            // Set as the peripheral to use and establish connection
            self.arduinoPeripheral = peripheral
            self.arduinoPeripheral.delegate = self
            self.centralManager.connectPeripheral(peripheral, options: nil)
        }
        else {
            self.statusLabel.text = "Arduino NOT Found"
        }
    }
    
    // Discover services of the peripheral
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print("\n\n Arduino Connected \n\n")
        self.statusLabel.text = "Connected to Arduino"
//        allowSending = true
        peripheral.discoverServices(nil)
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("\n\n Arduino disconnected \n\n")
        allowSending = false
    }
    
    // Check if the service discovered is a valid IR Temperature Service
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        self.statusLabel.text = "Looking at peripheral services"
        for service in peripheral.services! {
            let thisService = service as CBService
            if service.UUID == arduinoServiceUUID {
                // Discover characteristics of IR Temperature Service
                peripheral.discoverCharacteristics(nil, forService: thisService)
            }
            // Uncomment to print list of UUIDs
            print(thisService.UUID)
        }
    }
    
    // Enable notification and sensor for each characteristic of valid service
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {

        
        if (peripheral != self.arduinoPeripheral) {
            // Wrong Peripheral
            return
        }
        
        if (error != nil) {
            return
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.UUID == arduinoDataUUID {
                    self.positionCharacteristic = (characteristic)
                    peripheral.setNotifyValue(true, forCharacteristic: characteristic)
                    allowSending = true
                    // Send notification that Bluetooth is connected and all required characteristics are discovered
                    //self.sendBTServiceNotificationWithIsBluetoothConnected(true)
                }
            }
        }

        
    }
    
//    func sendPosition(position: UInt8) {
//    func sendPosition(position: Double) {
    func sendPosition(position: CMAcceleration) {
    
        /******** (2) CODE TO BE ADDED *******/

        // 2
        // Validate value
//        if position == lastPosition {
//            print("position equals to last, skipping")
//            return
//        }
            // 3
//        else if ((position < 0) || (position > 255)) {
//            print("position not in range, skipping")
//            return
//        }
        
        // 4
        // Send position to BLE Shield (if service exists and is connected)
        if arduinoPeripheral.state == .Connected {
//            print("is connected   sending: \(position)")
            writePosition(position)
//            allowSending = false
//            lastPosition = position
        }
//        if let bleService = btDiscoverySharedInstance.bleService {
//            bleService.writePosition(position)
//            lastPosition = position
//
//        }
        
        allowTX = false
        if timerTXDelay == nil {
            timerTXDelay = NSTimer.scheduledTimerWithTimeInterval(0.1,
                target: self,
                selector: #selector(ViewController.timerTXDelayElapsed),
                userInfo: nil,
                repeats: false)
        }
    
        
        
    }
    
//    func writePosition(position: UInt8) {

//    func writePosition(position: Double) {
    func writePosition(position: CMAcceleration) {
        /******** (1) CODE TO BE ADDED *******/
        
        // See if characteristic has been discovered before writing to it
        if let positionCharacteristic = self.positionCharacteristic {
            // Need a mutable var to pass to writeValue function
//            var value = Float(positionValue)
            let string = "\(Float(position.x)):\(Float(position.y)):\(Float(position.z))"
            var value = Float(position.x)
            let array = [Float(position.x), Float(position.y), Float(position.z)]
            print("is connected   sending: \(string)")
//            let data = NSData(bytes: &positionValue, length: sizeof(UInt8))
            let data2 = NSMutableData()
//            let data = NSData(bytes: &value, length: sizeof(Float))
            data2.appendBytes(&value, length: sizeof(Float))
            
//            for i in 0 ..< array.count {
//                let data = (string as NSString).dataUsingEncoding(NSUTF8StringEncoding)
            
                let data = (String(position.x)).dataUsingEncoding(NSUTF8StringEncoding)
                self.arduinoPeripheral?.writeValue(data!, forCharacteristic: positionCharacteristic, type: CBCharacteristicWriteType.WithResponse)
//            }
            
//            }
            
        }
    }
    
//    func writeHeading(heading: CLLocationDirection) {
    func writeHeading() {
        /******** (1) CODE TO BE ADDED *******/
        
        // See if characteristic has been discovered before writing to it
        if let positionCharacteristic = self.positionCharacteristic {
            // Need a mutable var to pass to writeValue function
            //            var value = Float(positionValue)

            
            //            let data = NSData(bytes: &positionValue, length: sizeof(UInt8))
//            let data = NSMutableData()
            //            let data = NSData(bytes: &value, length: sizeof(Float))
            
            
//            let value: Float = Float(heading as Double)
            
            let value = "\(self.arduinoCmd[0])\(self.arduinoCmd[1])\(self.arduinoCmd[2])"
            
            tempLabel.text = String(value)
            
            
//            print("is connecte sending: \(value)")
            
            
//            data.appendBytes(&value, length: sizeof(Float))
            
            //            for i in 0 ..< array.count {
            //                let data = (string as NSString).dataUsingEncoding(NSUTF8StringEncoding)
            
            let data = (String(value)).dataUsingEncoding(NSUTF8StringEncoding)
            self.arduinoPeripheral?.writeValue(data!, forCharacteristic: positionCharacteristic, type: CBCharacteristicWriteType.WithResponse)
            //            }
            
            //            }
            
        }
    }

    func timerTXDelayElapsed() {
        self.allowTX = true
        
        self.stopTimerTXDelay()
        
        // Send current slider position
//        self.sendPosition(UInt8(self.slider.value))
    }

    func stopTimerTXDelay() {
        if self.timerTXDelay == nil {
            return
        }
        
        timerTXDelay?.invalidate()
        self.timerTXDelay = nil
    }
    
    // MARK: - Location Delegate
    
    var counter = 0
    var updateHeading = false
    func locationManager(manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        
        if newHeading.headingAccuracy < 0 {
            return
        }
        
        //let theHeading = ((newHeading.trueHeading > 0) ? newHeading.trueHeading : newHeading.magneticHeading)
//        print("Heading did update \(newHeading.magneticHeading)")

        
        if (self.currentTrueHeading > (newHeading.trueHeading + 5)) {
//            print("left turn")
            self.arduinoCmd[0] = 1
            self.arduinoCmd[2] = 0
            self.currentTrueHeading = newHeading.trueHeading
//            if updateHeading == true {
//                self.headingChecker = newHeading.trueHeading
//                updateHeading = false
//            }
            
        } else if self.currentTrueHeading < (newHeading.trueHeading + 5) {
//            print("right turn")
            self.arduinoCmd[2] = 1
            self.arduinoCmd[0] = 0
            self.currentTrueHeading = newHeading.trueHeading
//            if updateHeading == true {
//                self.headingChecker = newHeading.trueHeading
//                updateHeading = false
//            }
        } else {
//            print("going straight")
            self.arduinoCmd[0] = 0
            self.arduinoCmd[2] = 0
        }
        
//        let theHeading = ((newHeading.trueHeading > 0) ? newHeading.trueHeading : newHeading.magneticHeading)
        //        print("Heading did update \(theHeading)")
//        self.currentTrueHeading = newHeading.trueHeading
        
        currentHeading = newHeading.magneticHeading
        
        /*
        if allowSending {
            writeHeading(newHeading.magneticHeading)
        }
        */
    }
    
    func locationManager(manager: CLLocationManager, didUpdateToLocation newLocation: CLLocation, fromLocation oldLocation: CLLocation) {
        print("speed \(newLocation.speed)")
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print(manager.location!.speed)
        print(locations.first?.speed)
    }
    

}


// LoadAUF - Hector Attemp
extension ViewController {


    
    
    func estimatePedestrianStatus(acceleration: CMAcceleration) {
        // Obtain the Euclidian Norm of the accelerometer data
        accelerometerDataInEuclidianNorm = sqrt((acceleration.x.roundTo(roundingPrecision) * acceleration.x.roundTo(roundingPrecision)) + (acceleration.y.roundTo(roundingPrecision) * acceleration.y.roundTo(roundingPrecision)) + (acceleration.z.roundTo(roundingPrecision) * acceleration.z.roundTo(roundingPrecision)))
        
        // Significant figure setting
        accelerometerDataInEuclidianNorm = accelerometerDataInEuclidianNorm.roundTo(roundingPrecision)
        
        // record 10 values
        // meaning values in a second
        // accUpdateInterval(0.1s) * 10 = 1s
        while accelerometerDataCount < 1 {
            accelerometerDataCount += 0.05
            
            accelerometerDataInASecond.append(accelerometerDataInEuclidianNorm)
            totalAcceleration += accelerometerDataInEuclidianNorm
            
            break   // required since we want to obtain data every acc cycle
        }
        
        // when acc values recorded
        // interpret them
        if accelerometerDataCount >= 1 {
            accelerometerDataCount = 0  // reset for the next round
            
            // Calculating the variance of the Euclidian Norm of the accelerometer data
            let accelerationMean = (totalAcceleration / 20.0).roundTo(roundingPrecision)
            var total: Double = 0.0
            
            for data in accelerometerDataInASecond {
                total += ((data-accelerationMean) * (data-accelerationMean)).roundTo(roundingPrecision)
            }
            
            total = total.roundTo(roundingPrecision)
            
            let result = (total / 20).roundTo(roundingPrecision)
            print("Result: \(result)")
            
            
            if (result < staticThreshold) {
                pedestrianStatus = "Static"
                self.arduinoCmd[1] = 0
            } else if ((staticThreshold < result) && (result <= slowWalkingThreshold)) {
                pedestrianStatus = "Slow Walking"
                self.arduinoCmd[1] = 1
            } else if (slowWalkingThreshold < result) {
                pedestrianStatus = "Fast Walking"
                self.arduinoCmd[1] = 1
            }
            
//            print("Pedestrian Status: \(pedestrianStatus)\n---\n\n")
            
            
            // reset for the next round
            accelerometerDataInASecond = []
            totalAcceleration = 0.0
        }
//        print("Status Left: \(arduinoCmd[0]) Walk: \(arduinoCmd[1]) Right: \(arduinoCmd[2])")
        //writeHeading()
        
        

    }
    
    func didHeadingUpdate() {
        
//        if headingChecker == currentTrueHeading {
//            counter += 1
//            if counter == 5 {
//                self.arduinoCmd[0] = 0
//                self.arduinoCmd[2] = 0
//            }
//        }
        if let _ = currentTrueHeading {
//            print("\n\n current heading exists \(headingChecker) -- \(currentTrueHeading)  -  \(counter)\n\n")
            if headingChecker != currentTrueHeading {
//                print("\n\nchanging heading\n\n")
                headingChecker = currentTrueHeading!
            } else {
                counter += 1
                if counter == 5 {
                    self.arduinoCmd[0] = 0
                    self.arduinoCmd[2] = 0
                    counter = 0
                }
            }
        }
        
        
        updateHeading = true
        secondsCounter += 1
        if secondsCounter == 10 {
            self.secondsCounter = 0
            print("\n\n\n Second has passed  \n\n\n")
        }
        writeHeading()
//        if currentTrueHeading == headingChecker {
//            //print("\n\n\n reset direction \n\n\n")
//            self.arduinoCmd[0] = 0
//            self.arduinoCmd[2] = 0
//        }
    }

    
}

extension Double {
        func roundTo(precision: Int) -> Double {
            let divisor = pow(10.0, Double(precision))
            return round(self * divisor) / divisor
        }
}

