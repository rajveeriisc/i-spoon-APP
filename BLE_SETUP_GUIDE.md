# BLE Configuration Guide

## Required Info.plist Entries

You MUST add the following entries to your Info.plist file for Bluetooth to work:

### 1. Bluetooth Usage Description (Required for iOS 13+)

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to your device and receive data.</string>
```

### 2. Optional: Bluetooth Peripheral Usage (if acting as peripheral)

```xml
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to advertise and communicate with other devices.</string>
```

### 3. Background Modes (Optional - for background BLE)

If you want to maintain the connection in the background, add Background Modes capability:

**In Xcode:**
1. Select your project target
2. Go to "Signing & Capabilities"
3. Click "+ Capability"
4. Add "Background Modes"
5. Check "Uses Bluetooth LE accessories"

This will add to your Info.plist:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

## Important Configuration Steps

### 1. Update Service and Characteristic UUIDs

In `BLEManager.swift`, replace these placeholders with your actual UUIDs:

```swift
private let serviceUUID = CBUUID(string: "YOUR-SERVICE-UUID")
private let characteristicUUID = CBUUID(string: "YOUR-CHARACTERISTIC-UUID")
```

Example:
```swift
private let serviceUUID = CBUUID(string: "180D") // Heart Rate Service
private let characteristicUUID = CBUUID(string: "2A37") // Heart Rate Measurement
```

### 2. Optional: Filter by Device Name

If you want to connect only to a specific device by name:

```swift
private let targetDeviceName: String? = "MyDevice" // Set your device name
```

## How It Works

### Automatic Connection
The BLEManager automatically:
1. Starts scanning when Bluetooth is powered on
2. Discovers devices advertising your service UUID
3. Connects to the first discovered device (or specific device by name)
4. Discovers services and characteristics
5. Enables notifications to continuously receive data
6. Automatically reconnects if disconnected

### Receiving Data
Data is received through notifications:
- When the peripheral sends data, `didUpdateValueFor characteristic` is called
- Data is automatically processed and added to the `receivedData` array
- The UI updates in real-time to show received data

### Data Format
By default, the manager tries to decode data as UTF-8 string. Modify the `processReceivedData()` method to handle your specific data format:

```swift
private func processReceivedData(_ data: Data) {
    // Your custom data processing here
}
```

## Usage in Your App

### SwiftUI App
Add the view to your app:

```swift
import SwiftUI

@main
struct YourApp: App {
    var body: some Scene {
        WindowGroup {
            BLEConnectionView()
        }
    }
}
```

### UIKit Integration
Create a hosting controller:

```swift
let bleView = BLEConnectionView()
let hostingController = UIHostingController(rootView: bleView)
present(hostingController, animated: true)
```

## Testing

1. Make sure your BLE peripheral is powered on and advertising
2. Launch the app
3. Grant Bluetooth permissions when prompted
4. The app will automatically start scanning and connect
5. Once connected, data will appear in the "Received Data" section

## Troubleshooting

### No Devices Found
- Check that your peripheral is advertising the correct service UUID
- Verify Bluetooth is enabled on your device
- Make sure the service UUID in the code matches your peripheral

### Connection Fails
- Check signal strength (device might be out of range)
- Verify the peripheral is not connected to another device
- Try restarting Bluetooth on your iOS device

### No Data Received
- Verify the characteristic supports notifications (notify property)
- Check that the peripheral is actually sending data
- Ensure the characteristic UUID is correct

### Background Connection
- Add Background Modes capability as described above
- Note: Background scanning is limited and connections may be maintained but new discoveries are restricted
- For true background operation, consider using Core Bluetooth's state preservation and restoration
