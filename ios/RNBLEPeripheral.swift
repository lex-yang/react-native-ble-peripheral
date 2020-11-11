//  Created by Eskel on 12/12/2018

import Foundation
import CoreBluetooth

@objc(BLEPeripheral)
class BLEPeripheral: RCTEventEmitter, CBPeripheralManagerDelegate {
    var advertising: Bool = false
    var hasListeners: Bool = false
    var name: String = "RN_BLE"
    var servicesMap = Dictionary<String, CBMutableService>()
    var manager: CBPeripheralManager!
    var startPromiseResolve: RCTPromiseResolveBlock?
    var startPromiseReject: RCTPromiseRejectBlock?
    
    var characteristicMap = Dictionary<String, UInt8>()
    
    override init() {
        super.init()
        manager = CBPeripheralManager(delegate: self, queue: nil, options: nil)
        print("BLEPeripheral initialized, advertising: \(advertising)")
    }
    
    //// PUBLIC METHODS

    @objc func setName(_ name: String) {
        self.name = name
        print("name set to \(name)")
    }
    
    @objc func isAdvertising(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
        resolve(advertising)
        print("called isAdvertising")
    }
    
    @objc(createService:primary:)
    func createService(_ uuid: String, primary: Bool) {
        let serviceUUID = CBUUID(string: uuid)
        let service = CBMutableService(type: serviceUUID, primary: primary)
        if(servicesMap.keys.contains(uuid) != true){
            servicesMap[uuid.uppercased()] = service
            //manager.add(service)
            print("created service \(uuid)")
        }
        else {
            alertJS("service \(uuid) already there")
        }
    }
    
    @objc(addCharacteristicToService:uuid:permissions:properties:)
    func addCharacteristicToService(_ serviceUUID: String, uuid: String, permissions: String, properties: String) {
        let characteristicUUID = CBUUID(string: uuid)
        
        var propertyValue: CBCharacteristicProperties
        switch properties {
        case "write":
            propertyValue = CBCharacteristicProperties.write
        default:
            propertyValue = CBCharacteristicProperties.read
        }
        
        var permissionValue: CBAttributePermissions
        switch permissions {
        case "write":
            permissionValue = CBAttributePermissions.writeable
        default:
            permissionValue = CBAttributePermissions.readable
        }
        
        let characteristic = CBMutableCharacteristic( type: characteristicUUID, properties: propertyValue, value: nil, permissions: permissionValue)
        
        if let service = servicesMap[serviceUUID.uppercased()] {
            if (service.characteristics == nil) {
                service.characteristics = [CBMutableCharacteristic]()
            }
            service.characteristics!.append(characteristic)
            print("added characteristic to service")
        }
        else {
            alertJS("create service before add characteristic !!!")
        }
    }
    
    @objc(publishService:)
    func publishService(_ uuid: String) {
        if let service = servicesMap[uuid.uppercased()] {
            manager.add(service)
            print("service: \(uuid) published .")
        }
    }
    
    @objc func updateValue(_ uuid: String, value data: UInt8) {
        let UUID = uuid.uppercased()
        characteristicMap[UUID] = data
        print("update characteristic: \(UUID) value \(data)")
    }
    
    @objc func start(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        if (manager.state != .poweredOn) {
            alertJS("Bluetooth turned off")
            return;
        }
        
        startPromiseResolve = resolve
        startPromiseReject = reject

        let advertisementData = [
            CBAdvertisementDataLocalNameKey: name,
            CBAdvertisementDataServiceUUIDsKey: getServiceUUIDArray()
            ] as [String : Any]
        manager.startAdvertising(advertisementData)
    }
    
    @objc func stop() {
        manager.stopAdvertising()
        advertising = false
        print("called stop")
    }

    @objc(sendNotificationToDevices:characteristicUUID:data:)
    func sendNotificationToDevices(_ serviceUUID: String, characteristicUUID: String, data: Data) {
        if(servicesMap.keys.contains(serviceUUID) == true){
            let service = servicesMap[serviceUUID]!
            let characteristic = getCharacteristicForService(service, characteristicUUID)
            if (characteristic == nil) { alertJS("service \(serviceUUID) does NOT have characteristic \(characteristicUUID)") }

            let char = characteristic as! CBMutableCharacteristic
            char.value = data
            let success = manager.updateValue( data, for: char, onSubscribedCentrals: nil)
            if (success){
                print("changed data for characteristic \(characteristicUUID)")
            } else {
                alertJS("failed to send changed data for characteristic \(characteristicUUID)")
            }

        } else {
            alertJS("service \(serviceUUID) does not exist")
        }
    }
    
    //// EVENTS

    // Respond to Read request
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest)
    {
        let UUID = request.characteristic.uuid.uuidString.uppercased()
        
        if (characteristicMap.keys.contains(UUID)) {
            request.value = Data([characteristicMap[UUID]!])
            manager.respond(to: request, withResult: .success)
        } else {
            alertJS("cannot read, characteristic not found")
        }
    }

    // Respond to Write request
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest])
    {
        for request in requests
        {
            let UUID = request.characteristic.uuid.uuidString.uppercased()
            
            if let data = request.value {
                sendEvent(withName: "writeEvent", body: [ "uuid": UUID, "value": data[0] ])
            }
         }
        manager.respond(to: requests[0], withResult: .success)
    }

    // Respond to Subscription to Notification events
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        let char = characteristic as! CBMutableCharacteristic
        print("subscribed centrals: \(String(describing: char.subscribedCentrals))")
    }

    // Respond to Unsubscribe events
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        let char = characteristic as! CBMutableCharacteristic
        print("unsubscribed centrals: \(String(describing: char.subscribedCentrals))")
    }

    // Service added
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        var msg: String
        var result: Bool
        if let error = error {
            msg = "error: \(error)"
            result = false
            alertJS(msg)
        }
        else {
            result = true
            msg = "service: \(service)"
            print(msg)
        }
        sendEvent(withName: "serviceAdded", body: [ "result": result, "uuid": service.uuid.uuidString])
    }

    // Bluetooth status changed
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        var state: Any
        if #available(iOS 10.0, *) {
            state = peripheral.state.description
        } else {
            state = peripheral.state
        }
        alertJS("BT state change: \(state)")
        
        sendEvent(withName: "stateUpdated", body: [ "state": state] )
    }

    // Advertising started
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            alertJS("advertising failed. error: \(error)")
            advertising = false
            startPromiseReject!("AD_ERR", "advertising failed", error)
            return
        }
        advertising = true
        startPromiseResolve!(advertising)
        print("advertising succeeded!")
    }
    
    //// HELPERS

    func getCharacteristic(_ characteristicUUID: CBUUID) -> CBCharacteristic? {
        for (uuid, service) in servicesMap {
            for characteristic in service.characteristics ?? [] {
                if (characteristic.uuid.isEqual(characteristicUUID) ) {
                    print("service \(uuid) does have characteristic \(characteristicUUID)")
                    if (characteristic is CBMutableCharacteristic) {
                        return characteristic
                    }
                    print("but it is not mutable")
                } else {
                    alertJS("characteristic you are trying to access doesn't match")
                }
            }
        }
        return nil
    }

    func getCharacteristicForService(_ service: CBMutableService, _ characteristicUUID: String) -> CBCharacteristic? {
        for characteristic in service.characteristics ?? [] {
            if (characteristic.uuid.isEqual(characteristicUUID) ) {
                print("service \(service.uuid) does have characteristic \(characteristicUUID)")
                if (characteristic is CBMutableCharacteristic) {
                    return characteristic
                }
                print("but it is not mutable")
            } else {
                alertJS("characteristic you are trying to access doesn't match")
            }
        }
        return nil
    }

    func getServiceUUIDArray() -> Array<CBUUID> {
        var serviceArray = [CBUUID]()
        for (_, service) in servicesMap {
            serviceArray.append(service.uuid)
        }
        return serviceArray
    }

    func alertJS(_ message: Any) {
        print(message)
        if(hasListeners) {
            sendEvent(withName: "onWarning", body: message)
        }
    }

    //@objc override func supportedEvents() -> [String]! { return ["onWarning"] }
    override func startObserving() { hasListeners = true }
    override func stopObserving() { hasListeners = false }
    @objc override static func requiresMainQueueSetup() -> Bool { return false }
    
}

@available(iOS 10.0, *)
extension CBManagerState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .poweredOff: return ".poweredOff"
        case .poweredOn: return ".poweredOn"
        case .resetting: return ".resetting"
        case .unauthorized: return ".unauthorized"
        case .unknown: return ".unknown"
        case .unsupported: return ".unsupported"
        }
    }
}
