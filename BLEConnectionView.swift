import SwiftUI

struct BLEConnectionView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var showingDeviceList = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Connection Status
                connectionStatusSection
                
                // Controls
                controlsSection
                
                // Signal Strength
                if bleManager.isConnected {
                    signalStrengthSection
                }
                
                // Received Data
                receivedDataSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("BLE Connection")
            .sheet(isPresented: $showingDeviceList) {
                deviceListSheet
            }
        }
    }
    
    // MARK: - View Components
    
    private var connectionStatusSection: some View {
        VStack(spacing: 10) {
            Image(systemName: statusIcon)
                .font(.system(size: 60))
                .foregroundStyle(statusColor)
            
            Text(statusText)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(statusDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(statusColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            if !bleManager.isConnected {
                Button {
                    bleManager.autoConnect()
                } label: {
                    Label(bleManager.isScanning ? "Scanning..." : "Start Scanning", 
                          systemImage: "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(bleManager.isScanning)
                
                if bleManager.isScanning {
                    Button {
                        bleManager.stopScanning()
                    } label: {
                        Label("Stop Scanning", systemImage: "stop.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                if !bleManager.discoveredPeripherals.isEmpty {
                    Button {
                        showingDeviceList = true
                    } label: {
                        Label("Show Devices (\(bleManager.discoveredPeripherals.count))", 
                              systemImage: "list.bullet")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button(role: .destructive) {
                    bleManager.disconnect()
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button {
                    bleManager.readSignalStrength()
                } label: {
                    Label("Update Signal Strength", systemImage: "wifi")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var signalStrengthSection: some View {
        VStack(spacing: 8) {
            Label("Signal Strength", systemImage: "wifi")
                .font(.headline)
            
            Text("\(bleManager.signalStrength) dBm")
                .font(.title3)
                .fontWeight(.medium)
            
            signalStrengthBar
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var signalStrengthBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(signalColor)
                    .frame(width: signalBarWidth(for: geometry.size.width), height: 8)
            }
        }
        .frame(height: 8)
    }
    
    private var receivedDataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Received Data", systemImage: "doc.text")
                    .font(.headline)
                
                Spacer()
                
                if !bleManager.receivedData.isEmpty {
                    Button {
                        bleManager.receivedData.removeAll()
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .labelStyle(.iconOnly)
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                }
            }
            
            ScrollView {
                if bleManager.receivedData.isEmpty {
                    ContentUnavailableView(
                        "No Data Received",
                        systemImage: "tray",
                        description: Text("Data will appear here when received from the BLE device")
                    )
                    .frame(minHeight: 200)
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(bleManager.receivedData.enumerated()), id: \.offset) { index, data in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                                
                                Text(data)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.secondary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var deviceListSheet: some View {
        NavigationStack {
            List(bleManager.discoveredPeripherals, id: \.identifier) { peripheral in
                Button {
                    bleManager.connect(to: peripheral)
                    showingDeviceList = false
                } label: {
                    VStack(alignment: .leading) {
                        Text(peripheral.name ?? "Unknown Device")
                            .font(.headline)
                        
                        Text(peripheral.identifier.uuidString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Available Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingDeviceList = false
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusIcon: String {
        switch bleManager.connectionState {
        case .disconnected:
            return "antenna.radiowaves.left.and.right.slash"
        case .scanning:
            return "antenna.radiowaves.left.and.right"
        case .connecting:
            return "circle.dotted"
        case .connected:
            return "checkmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch bleManager.connectionState {
        case .disconnected:
            return .red
        case .scanning:
            return .orange
        case .connecting:
            return .blue
        case .connected:
            return .green
        }
    }
    
    private var statusText: String {
        switch bleManager.connectionState {
        case .disconnected:
            return "Disconnected"
        case .scanning:
            return "Scanning"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        }
    }
    
    private var statusDescription: String {
        switch bleManager.connectionState {
        case .disconnected:
            return "No device connected"
        case .scanning:
            return "Looking for devices..."
        case .connecting:
            return "Establishing connection..."
        case .connected:
            return "Ready to receive data"
        }
    }
    
    private var signalColor: Color {
        let rssi = bleManager.signalStrength
        if rssi >= -50 {
            return .green
        } else if rssi >= -70 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private func signalBarWidth(for maxWidth: CGFloat) -> CGFloat {
        let rssi = bleManager.signalStrength
        // RSSI typically ranges from -100 (weak) to -30 (strong)
        let normalized = max(0, min(100, 100 + rssi))
        return maxWidth * CGFloat(normalized) / 100.0
    }
}

#Preview {
    BLEConnectionView()
}
