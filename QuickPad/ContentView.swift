//
//  ContentView.swift
//  QuickPad
//
//  Created by panyingying on 2020/12/6.
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    let delegate = Delegate()
    let manager = CBCentralManager()

    var body: some View {
        VStack {
            Text("\(manager.state.rawValue)")
            Button(action: {
                print("initCentral")
                manager.delegate = delegate
            }, label: {
                Text("initCentral")
            })
            HStack {
                Button(action: {
                    print("startScan")
                    manager.scanForPeripherals(withServices: nil)
                }, label: {
                    Text("startScan")
                })
                Button(action: {
                    print("stopScan")
                    manager.stopScan()
                }, label: {
                    Text("stopScan")
                })
            }
            HStack {
                Button(action: {
                    print("connect")
                    manager.connect(delegate.peripheral!)
                }, label: {
                    Text("connect")
                })
                Button(action: {
                    print("disconnect")
                    manager.cancelPeripheralConnection(delegate.peripheral!)
                }, label: {
                    Text("disconnect")
                })
            }
            Button(action: {
                print("initPeripheral")
                delegate.peripheral?.delegate = delegate
                delegate.peripheral?.discoverServices(nil)
            }, label: {
                Text("initPeripheral")
            })
            HStack {
                Button(action: {
                    print("configCharacteristic")
                    delegate.configCharacteristic()
                }, label: {
                    Text("configCharacteristic")
                })
                Button(action: {
                    print("checkAccess")
                    delegate.checkAccess()
                }, label: {
                    Text("checkAccess")
                })
            }
            HStack {
                Button(action: {
                    print("getLargeDataInfo")
                    delegate.getLargeDataInfo()
                }, label: {
                    Text("getLargeDataInfo")
                })
            }
        }
    }
}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}

let WOODEMI_PREFIX = Data(bytes: [0x57, 0x44, 0x4d]) // "WDM"

let SUFFIX = "ba5e-f4ee-5ca1-eb1e5e4b1ce0"
let SERV__COMMAND = "57444d01-\(SUFFIX)"
let CHAR__COMMAND_REQUEST = "57444e02-\(SUFFIX)"
let CHAR__COMMAND_RESPONSE = CHAR__COMMAND_REQUEST

let SERV__FILE_INPUT = "57444d03-\(SUFFIX)"
let CHAR__FILE_INPUT_CONTROL_REQUEST = "57444d04-\(SUFFIX)"
let CHAR__FILE_INPUT_CONTROL_RESPONSE = CHAR__FILE_INPUT_CONTROL_REQUEST
let CHAR__FILE_INPUT = "57444d05-\(SUFFIX)"

let imageId = Data(bytes: [0x00, 0x01])
let imageVersion = Data(bytes: [
    0x01, 0x00, 0x00, // Build Version
    0x41, // Stack Version
    0x11, 0x11, 0x11, // Hardware Id
    0x01 // Manufacturer Id
])

extension ContentView {
    class Delegate: NSObject {
        var peripheral: CBPeripheral?
        
        func configCharacteristic() {
            let command = peripheral!.getCharacteristic(CHAR__COMMAND_RESPONSE, of: SERV__COMMAND)
            peripheral!.setNotifyValue(true, for: command)

            let inputControl = peripheral!.getCharacteristic(CHAR__FILE_INPUT_CONTROL_RESPONSE, of: SERV__FILE_INPUT)
            peripheral!.setNotifyValue(true, for: inputControl)
        }

        func checkAccess() {
            let c = peripheral!.getCharacteristic(CHAR__COMMAND_REQUEST, of: SERV__COMMAND)
            peripheral!.writeValue(Data(bytes: [0x01, 0x0A, 0x00, 0x00, 0x00, 0x01]), for: c, type: .withResponse)
        }
        
        func getLargeDataInfo() {
            let c = peripheral!.getCharacteristic(CHAR__FILE_INPUT_CONTROL_REQUEST, of: SERV__FILE_INPUT)
            peripheral!.writeValue(Data(bytes: [0x02]) + imageId + imageVersion, for: c, type: .withResponse)
        }
    }
}

extension ContentView.Delegate: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("centralManagerDidUpdateState: \(central.state)")
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("centralManager:didDiscoverPeripheral \(peripheral.name) \(peripheral.identifier)")
        guard let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data else {
            return
        }

        if manufacturerData.starts(with: WOODEMI_PREFIX) {
            self.peripheral = peripheral
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("centralManager:didConnect \(peripheral.identifier)")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("centralManager:didDisconnectPeripheral: \(peripheral.identifier) error: \(error)")
    }
}

extension ContentView.Delegate: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("peripheral: \(peripheral.identifier) didDiscoverServices: \(error)")
        for service in peripheral.services! {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics! {
            print("peripheral:didDiscoverCharacteristicsForService (\(service.uuid), \(characteristic.uuid)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("peripheral:didUpdateNotificationStateFor \(characteristic.uuid) \(characteristic.isNotifying)")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("peripheral:didWriteValueForCharacteristic \(characteristic.uuid) \(characteristic.value as? NSData) error: \(error)")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("peripheral:didUpdateValueForForCharacteristic \(characteristic.uuid) \(characteristic.value as! NSData) error: \(error)")
    }
}

let GSS_SUFFIX = "0000-1000-8000-00805f9b34fb"

extension CBUUID {
    public var uuidStr: String {
        get {
            uuidString.lowercased()
        }
    }
}

extension CBPeripheral {
    public func getCharacteristic(_ characteristic: String, of service: String) -> CBCharacteristic {
        let s = self.services?.first {
            $0.uuid.uuidStr == service || "0000\($0.uuid.uuidStr)-\(GSS_SUFFIX)" == service
        }
        let c = s?.characteristics?.first {
            $0.uuid.uuidStr == characteristic || "0000\($0.uuid.uuidStr)-\(GSS_SUFFIX)" == characteristic
        }
        return c!
    }
}
