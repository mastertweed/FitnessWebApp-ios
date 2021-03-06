/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import CoreBluetooth
//import Charts

let url = URL(string: "https://httpbin.org/get?hello=yes")

//let urlSessionsCount = URL(string: "http://localhost:3000/sessions/count")
let urlSessionsCount = URL(string: "https://76f2-8-44-146-213.ngrok.io/sessions/count")

//let urlSessionsCreate = URL(string: "http://localhost:3000/sessions")
//let urlSessionsCreate = URL(string: "https://76f2-8-44-146-213.ngrok.io/sessions")

let heartRateServiceCBUUID = CBUUID(string: "0x180D")
let heartRateMeasurementCharacteristicCBUUID = CBUUID(string: "2A37")
let bodySensorLocationCharacteristicCBUUID = CBUUID(string: "2A38")

//var heartRateData: [Int] = []

var trackingData = false
var sessionID = 0

struct heartrateModel: Decodable {
  let session: Int
  let heartrate: Int
}

class HRMViewController: UIViewController {

  @IBOutlet weak var heartRateLabel: UILabel!
  @IBOutlet weak var bodySensorLocationLabel: UILabel!

  @IBOutlet weak var sendDataButton: UIButton!
  @IBOutlet weak var dataStatusLabel: UILabel!
    
  @IBOutlet weak var startTrackingButton: UIButton!
  
  var centralManager: CBCentralManager!
  var heartRatePeripheral: CBPeripheral!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    startTrackingButton.backgroundColor = UIColor.green
        
    centralManager = CBCentralManager(delegate: self, queue: nil)

    // Make the digits monospaces to avoid shifting when the numbers change
    heartRateLabel.font = UIFont.monospacedDigitSystemFont(ofSize: heartRateLabel.font!.pointSize, weight: .regular)
  }
  
  @IBAction func startTracking(_ sender: Any) {
    if (trackingData == false) {
      startTrackingButton.backgroundColor = UIColor.red
      startTrackingButton.setTitle("Stop Tracking", for: .normal)
      
      // Send HTTP Request to get sessions count
      guard let requestUrl = urlSessionsCount else { fatalError() }
      var request = URLRequest(url: requestUrl)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpMethod = "GET"

      let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
          if let error = error {
              print("Error took place \(error)")
              return
          } else {
            if let data = data {
              if let dataString = String(data: data, encoding: .utf8) {
                print("Data from GET sessions count = \(dataString)")
                sessionID = Int(dataString.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789.").inverted)) ?? 0
                sessionID += 1
                print("This is the sessionID= \(sessionID)")
                
                // Send HTTP Request to create new entry in sessions
                let urlSessionsCreate = URL(string: "https://76f2-8-44-146-213.ngrok.io/sessions" + "/\(sessionID)" )
                guard let requestUrl = urlSessionsCreate else { fatalError() }
                var request2 = URLRequest(url: requestUrl)
                request2.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request2.httpMethod = "GET"
                let task2 = URLSession.shared.dataTask(with: request2) { (data, response, error) in
                  if let error = error {
                      print("Error took place \(error)")
                      return
                  }
                }
                task2.resume()
                
                // Tell device to start tracking heartrate
                trackingData = true
              }
            }
          }
      }
      task.resume()
      
      
    } else {
      startTrackingButton.backgroundColor = UIColor.green
      startTrackingButton.setTitle("Start Tracking", for: .normal)
      trackingData = false
    }
  }
  
  @IBAction func buttonTouch(_ sender: Any) {
    dataStatusLabel.text = "Hello"
  
  }
  
  func onHeartRateReceived(_ heartRate: Int) {
    heartRateLabel.text = String(heartRate)
    print("BPM: \(heartRate)")
    
    // If tracking data then send GET request to server
    if trackingData == true {
      // Send HTTP Request to create new entry in heartrate
      let urlHeartrateCreate = URL(string: "https://76f2-8-44-146-213.ngrok.io/heartrate" + "/\(sessionID)" + "/\(heartRate)" )
      guard let requestUrl = urlHeartrateCreate else { fatalError() }
      var request = URLRequest(url: requestUrl)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpMethod = "GET"
      let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
            print("Error took place \(error)")
            return
        }
      }
      task.resume()
    }
    
  }
  
}

extension HRMViewController: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .unknown:
      print("central.state is .unknown")
    case .resetting:
      print("central.state is .resetting")
    case .unsupported:
      print("central.state is .unsupported")
    case .unauthorized:
      print("central.state is .unauthorized")
    case .poweredOff:
      print("central.state is .poweredOff")
    case .poweredOn:
      print("central.state is .poweredOn")
      centralManager.scanForPeripherals(withServices: [heartRateServiceCBUUID])
    }
  }

  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                      advertisementData: [String : Any], rssi RSSI: NSNumber) {
    print(peripheral)
    heartRatePeripheral = peripheral
    heartRatePeripheral.delegate = self
    centralManager.stopScan()
    centralManager.connect(heartRatePeripheral)
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    print("Connected!")
    heartRatePeripheral.discoverServices([heartRateServiceCBUUID])
//    let startDateTime = Date()
  }
}

extension HRMViewController: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard let services = peripheral.services else { return }
    for service in services {
      print(service)
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard let characteristics = service.characteristics else { return }

    for characteristic in characteristics {
      print(characteristic)

      if characteristic.properties.contains(.read) {
        print("\(characteristic.uuid): properties contains .read")
        peripheral.readValue(for: characteristic)
      }
      if characteristic.properties.contains(.notify) {
        print("\(characteristic.uuid): properties contains .notify")
        peripheral.setNotifyValue(true, for: characteristic)
      }
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    switch characteristic.uuid {
    case bodySensorLocationCharacteristicCBUUID:
      let bodySensorLocation = bodyLocation(from: characteristic)
      bodySensorLocationLabel.text = bodySensorLocation
    case heartRateMeasurementCharacteristicCBUUID:
      let bpm = heartRate(from: characteristic)
      onHeartRateReceived(bpm)
    default:
      print("Unhandled Characteristic UUID: \(characteristic.uuid)")
    }
  }

  private func bodyLocation(from characteristic: CBCharacteristic) -> String {
    guard let characteristicData = characteristic.value,
      let byte = characteristicData.first else { return "Error" }

    switch byte {
    case 0: return "Other"
    case 1: return "Chest"
    case 2: return "Wrist"
    case 3: return "Finger"
    case 4: return "Hand"
    case 5: return "Ear Lobe"
    case 6: return "Foot"
    default:
      return "Reserved for future use"
    }
  }

  private func heartRate(from characteristic: CBCharacteristic) -> Int {
    guard let characteristicData = characteristic.value else { return -1 }
    let byteArray = [UInt8](characteristicData)

    // See: https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.heart_rate_measurement.xml
    // The heart rate mesurement is in the 2nd, or in the 2nd and 3rd bytes, i.e. one one or in two bytes
    // The first byte of the first bit specifies the length of the heart rate data, 0 == 1 byte, 1 == 2 bytes
    let firstBitValue = byteArray[0] & 0x01
    if firstBitValue == 0 {
      // Heart Rate Value Format is in the 2nd byte
      return Int(byteArray[1])
    } else {
      // Heart Rate Value Format is in the 2nd and 3rd bytes
      return (Int(byteArray[1]) << 8) + Int(byteArray[2])
    }
  }
}
