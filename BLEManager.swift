import Foundation
import CoreBluetooth
import os.log

@MainActor
class BLEManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var receivedData: [String] = []
    @Published var connectionState: ConnectionState = .disconnected
    @Published var signalStrength: Int = 0
    
    // MARK: - Properties
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var targetCharacteristic: CBCharacteristic?
    
    // Replace these with your device's service and characteristic UUIDs
    private let serviceUUID = CBUUID(string: "YOUR-SERVICE-UUID")
    private let characteristicUUID = CBUUID(string: "YOUR-CHARACTERISTIC-UUID")
    
    // Optional: If you want to filter by device name
    private let targetDeviceName: String? = nil // Set to your device name if needed
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BLE", category: "BLEManager")
    
    // Connection state enum
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case scanning
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        // Initialize with main queue to ensure all delegate callbacks are on main thread
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    // MARK: - Public Methods
    
    /// Start scanning for peripherals
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            logger.warning("Cannot start scanning - Bluetooth is not powered on")
            return
        }
        
        logger.info("Starting BLE scan...")
        connectionState = .scanning
        isScanning = true
        discoveredPeripherals.removeAll()
        
        // Scan for devices advertising the service UUID
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }
    
    /// Stop scanning for peripherals
    func stopScanning() {
        guard isScanning else { return }
        
        logger.info("Stopping BLE scan")
        centralManager.stopScan()
        isScanning = false
        if !isConnected {
            connectionState = .disconnected
        }
    }
    
    /// Connect to a specific peripheral
    func connect(to peripheral: CBPeripheral) {
        logger.info("Attempting to connect to peripheral: \(peripheral.identifier)")
        connectionState = .connecting
        
        // Stop scanning when attempting to connect
        if isScanning {
            stopScanning()
        }
        
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    /// Disconnect from the current peripheral
    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        
        logger.info("Disconnecting from peripheral")
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    /// Auto-connect to the first discovered device (useful for single device scenarios)
    func autoConnect() {
        guard centralManager.state == .poweredOn else {
            logger.warning("Cannot auto-connect - Bluetooth is not powered on")
            return
        }
        
        startScanning()
    }
    
    /// Send data to the connected peripheral (if characteristic supports write)
    func sendData(_ data: Data) {
        guard let peripheral = connectedPeripheral,
              let characteristic = targetCharacteristic else {
            logger.warning("Cannot send data - no connected peripheral or characteristic")
            return
        }
        
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        logger.info("Sent data: \(data.count) bytes")
    }
    
    /// Read RSSI (signal strength) from connected peripheral
    func readSignalStrength() {
        guard let peripheral = connectedPeripheral, isConnected else { return }
        peripheral.readRSSI()
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                logger.info("Bluetooth is powered on and ready")
                // Automatically start scanning when Bluetooth becomes available
                autoConnect()
                
            case .poweredOff:
                logger.warning("Bluetooth is powered off")
                connectionState = .disconnected
                isConnected = false
                
            case .resetting:
                logger.info("Bluetooth is resetting")
                
            case .unauthorized:
                logger.error("Bluetooth access is unauthorized")
                
            case .unsupported:
                logger.error("Bluetooth is not supported on this device")
                
            case .unknown:
                logger.info("Bluetooth state is unknown")
                
            @unknown default:
                logger.warning("Unknown Bluetooth state")
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, 
                                   didDiscover peripheral: CBPeripheral, 
                                   advertisementData: [String : Any], 
                                   rssi RSSI: NSNumber) {
        Task { @MainActor in
            let deviceName = peripheral.name ?? "Unknown Device"
            logger.info("Discovered peripheral: \(deviceName) (\(peripheral.identifier)) RSSI: \(RSSI)")
            
            // Filter by device name if specified
            if let targetName = targetDeviceName {
                guard deviceName == targetName else { return }
            }
            
            // Add to discovered list if not already present
            if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredPeripherals.append(peripheral)
            }
            
            // Auto-connect to the first discovered device
            if connectedPeripheral == nil {
                connect(to: peripheral)
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            logger.info("Successfully connected to peripheral: \(peripheral.name ?? "Unknown")")
            isConnected = true
            connectionState = .connected
            
            // Discover services
            peripheral.discoverServices([serviceUUID])
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, 
                                   didFailToConnect peripheral: CBPeripheral, 
                                   error: Error?) {
        Task { @MainActor in
            logger.error("Failed to connect to peripheral: \(error?.localizedDescription ?? "Unknown error")")
            connectionState = .disconnected
            isConnected = false
            
            // Retry scanning
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.startScanning()
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, 
                                   didDisconnectPeripheral peripheral: CBPeripheral, 
                                   error: Error?) {
        Task { @MainActor in
            if let error = error {
                logger.error("Peripheral disconnected with error: \(error.localizedDescription)")
            } else {
                logger.info("Peripheral disconnected")
            }
            
            isConnected = false
            connectionState = .disconnected
            connectedPeripheral = nil
            targetCharacteristic = nil
            
            // Automatically try to reconnect
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.startScanning()
            }
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error = error {
                logger.error("Error discovering services: \(error.localizedDescription)")
                return
            }
            
            guard let services = peripheral.services else { return }
            
            logger.info("Discovered \(services.count) service(s)")
            
            // Find the target service and discover its characteristics
            for service in services {
                if service.uuid == serviceUUID {
                    logger.info("Found target service: \(service.uuid)")
                    peripheral.discoverCharacteristics([characteristicUUID], for: service)
                }
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, 
                               didDiscoverCharacteristicsFor service: CBService, 
                               error: Error?) {
        Task { @MainActor in
            if let error = error {
                logger.error("Error discovering characteristics: \(error.localizedDescription)")
                return
            }
            
            guard let characteristics = service.characteristics else { return }
            
            logger.info("Discovered \(characteristics.count) characteristic(s)")
            
            // Find the target characteristic and subscribe to notifications
            for characteristic in characteristics {
                if characteristic.uuid == characteristicUUID {
                    logger.info("Found target characteristic: \(characteristic.uuid)")
                    targetCharacteristic = characteristic
                    
                    // Enable notifications to continuously receive data
                    if characteristic.properties.contains(.notify) {
                        peripheral.setNotifyValue(true, for: characteristic)
                        logger.info("Subscribed to characteristic notifications")
                    }
                    
                    // Read initial value if readable
                    if characteristic.properties.contains(.read) {
                        peripheral.readValue(for: characteristic)
                    }
                }
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, 
                               didUpdateValueFor characteristic: CBCharacteristic, 
                               error: Error?) {
        Task { @MainActor in
            if let error = error {
                logger.error("Error reading characteristic value: \(error.localizedDescription)")
                return
            }
            
            guard let data = characteristic.value else { return }
            
            logger.info("Received data: \(data.count) bytes")
            
            // Process the received data
            processReceivedData(data)
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, 
                               didWriteValueFor characteristic: CBCharacteristic, 
                               error: Error?) {
        Task { @MainActor in
            if let error = error {
                logger.error("Error writing characteristic value: \(error.localizedDescription)")
            } else {
                logger.info("Successfully wrote value to characteristic")
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, 
                               didUpdateNotificationStateFor characteristic: CBCharacteristic, 
                               error: Error?) {
        Task { @MainActor in
            if let error = error {
                logger.error("Error updating notification state: \(error.localizedDescription)")
                return
            }
            
            if characteristic.isNotifying {
                logger.info("Notifications enabled for characteristic: \(characteristic.uuid)")
            } else {
                logger.info("Notifications disabled for characteristic: \(characteristic.uuid)")
            }
        }
    }
    
    nonisolated func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        Task { @MainActor in
            if let error = error {
                logger.error("Error reading RSSI: \(error.localizedDescription)")
                return
            }
            
            signalStrength = RSSI.intValue
            logger.debug("Signal strength: \(RSSI) dBm")
        }
    }
    
    // MARK: - Data Processing
    
    private func processReceivedData(_ data: Data) {
        // Convert data to string (adjust based on your data format)
        if let string = String(data: data, encoding: .utf8) {
            receivedData.append(string)
            logger.info("Received string: \(string)")
        } else {
            // Handle binary data
            let hexString = data.map { String(format: "%02x", $0) }.joined()
            receivedData.append("Hex: \(hexString)")
            logger.info("Received hex: \(hexString)")
        }
        
        // Keep only the last 100 messages to prevent memory issues
        if receivedData.count > 100 {
            receivedData.removeFirst()
        }
    }
}
