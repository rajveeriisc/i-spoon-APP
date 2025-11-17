# 📊 Data Synchronization Guide - SmartSpoon App

## 🎯 Overview
This document explains how data is synchronized across different pages in the SmartSpoon app using the **Unified Data Service**.

## 🔗 Interconnected Parameters

### 1. **Temperature Data** 🌡️
**Connected Pages:**
- **Home Page** (`TemperatureDisplay`)
- **Insights Dashboard** (`TemperatureSection`)

**Data Flow:**
```
BLE Device → BleController.lastPacket.temperatureC
     ↓
UnifiedDataService (bridges data)
     ↓
├── Home Page (real-time temperature)
└── Insights Dashboard (temperature with analytics)
```

**Implementation:**
- Home: `dataService.foodTempC` and `dataService.heaterTempC`
- Insights: `controller.temperature` (synced with BLE via UnifiedDataService)

---

### 2. **Eating Metrics** 🍽️
**Connected Pages:**
- **Home Page** (`EatingAnalysisCard`)
- **Insights Dashboard** (`SummaryCards`, `DailyFoodTimeline`)

**Parameters:**
- `totalBites` - Total number of bites taken
- `avgBiteTime` - Average time per bite (seconds)
- `eatingSpeed` - Speed classification (Slow/Medium/Fast)
- `eatingPaceBpm` - Bites per minute

**Data Flow:**
```
InsightsController.summary (MealSummary)
     ↓
UnifiedDataService
     ↓
├── Home Page: Shows totalBites, avgBiteTime, eatingSpeed
└── Insights Dashboard: Shows detailed analysis with charts
```

**Implementation:**
- Home: `dataService.totalBites`, `dataService.avgBiteTime`, `dataService.eatingSpeed`
- Insights: `controller.summary.totalBites`, `controller.summary.eatingPaceBpm`

---

### 3. **Tremor Data** 🤝
**Pages:**
- **Insights Dashboard Only** (`TremorCharts`, `SummaryCards`)

**Parameters:**
- `currentMagnitude` - Current tremor magnitude (rad/s)
- `peakFrequencyHz` - Peak frequency (Hz)
- `level` - Tremor level (Low/Moderate/High)
- `tremorIndex` - Numeric index (0-100)

**Data Flow:**
```
InsightsController.tremor (TremorMetrics)
     ↓
UnifiedDataService
     ↓
Insights Dashboard: Real-time waveform + radial gauge
```

---

## 🏗️ Architecture

### **UnifiedDataService**
Location: `lib/services/unified_data_service.dart`

**Purpose:** Single source of truth that bridges BLE and Insights data

**Key Features:**
1. **Real-time Sync**: Listens to both BleController and InsightsController
2. **Priority System**: Prefers BLE temperature (real device) over mock data
3. **Computed Properties**: Derives `eatingSpeed` and `avgBiteTime` automatically
4. **Auto-notification**: Updates all consumers when data changes

**Provided in:** `main.dart` using `ChangeNotifierProxyProvider2`

---

## 🔄 How Data Updates Propagate

### Example: Temperature Update
1. **BLE Device** sends new temperature packet
2. **BleController** receives and stores `lastPacket.temperatureC`
3. **UnifiedDataService** detects BLE update via listener
4. **UnifiedDataService** updates its `_temperature` field
5. **UnifiedDataService** calls `notifyListeners()`
6. **All consumers rebuild:**
   - Home → TemperatureDisplay shows new value
   - Insights → TemperatureSection shows new value

### Example: Eating Metrics Update
1. **InsightsController** updates `summary` from repository
2. **UnifiedDataService** syncs data every 500ms
3. **UnifiedDataService** detects change and notifies
4. **All consumers rebuild:**
   - Home → EatingAnalysisCard shows new values
   - Insights → SummaryCards + Charts show new values

---

## 📝 Implementation Pattern

### Before (Disconnected):
```dart
// Home Page - Hardcoded
InfoColumn(value: '156', unit: 'Total Bites')

// Insights Page - Different source
Text('${controller.summary?.totalBites ?? 0}')
```

### After (Connected):
```dart
// Both pages use UnifiedDataService
Consumer<UnifiedDataService>(
  builder: (context, dataService, _) {
    return InfoColumn(
      value: dataService.totalBites.toString(),
      unit: 'Total Bites',
    );
  },
)
```

---

## 🚀 Benefits

✅ **Single Source of Truth**: One place for all shared data
✅ **Automatic Sync**: Changes in one place update everywhere
✅ **Type Safety**: Compile-time checks prevent mismatches
✅ **Real-time Updates**: BLE data flows seamlessly to all screens
✅ **Maintainable**: Easy to add new metrics or pages

---

## 📦 Files Modified

### Created:
- `lib/services/unified_data_service.dart` - Main data bridge

### Updated:
- `lib/main.dart` - Added global providers
- `lib/pages/home_page.dart` - Updated TemperatureDisplay & EatingAnalysisCard
- `lib/features/home/widgets/home_cards.dart` - Updated TemperatureCard & EatingAnalysisCard
- `lib/features/insights/presentation/widgets/*` - Enhanced with animations

---

## 🎨 Visual Data Flow

```
┌─────────────────┐
│   BLE Device    │ (Real sensor data)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ BleController   │ (lastPacket)
└────────┬────────┘
         │
         ├────────────┐
         │            │
         ▼            ▼
┌──────────────────────────────┐
│   UnifiedDataService         │
│  (Bridges & Synchronizes)    │
└──────────┬───────────────────┘
           │
           ├──────────────────┐
           │                  │
           ▼                  ▼
    ┌──────────┐      ┌──────────────┐
    │   Home   │      │   Insights   │
    │   Page   │      │  Dashboard   │
    └──────────┘      └──────────────┘
```

---

## 🔧 Adding New Synchronized Data

To add a new synchronized parameter:

1. **Add getter to UnifiedDataService:**
```dart
double get myNewMetric => _insightsController.someValue ?? 0;
```

2. **Update sync logic if needed:**
```dart
void _syncFromInsights() {
  // Add your sync logic
  if (_insightsController.newData != null) {
    notifyListeners();
  }
}
```

3. **Use in any page:**
```dart
Consumer<UnifiedDataService>(
  builder: (context, dataService, _) {
    return Text('${dataService.myNewMetric}');
  },
)
```

---

## ✅ Testing

All data synchronization has been tested and verified:
- ✅ Temperature syncs from BLE to both pages
- ✅ Eating metrics update consistently
- ✅ Tremor data displays in insights
- ✅ Empty state changes propagate correctly
- ✅ No linting errors
- ✅ No runtime errors

---

## 🐛 Bug Fixes

### Fixed: Bite Events Empty State Synchronization (Nov 11, 2025)
**Issue:** The `isNotEmpty` guard in bite events synchronization prevented empty list states from being propagated to consumers.

**Before:**
```dart
if (_insightsController.bites.isNotEmpty &&
    _biteEvents != _insightsController.bites) {
  _biteEvents = _insightsController.bites;
  hasChanges = true;
}
```

**Problem:** If bite events list became empty, the condition would fail (`isNotEmpty == false`), preventing consumers from knowing the list was cleared.

**After:**
```dart
// Sync bite events (including empty state)
if (_biteEvents != _insightsController.bites) {
  _biteEvents = _insightsController.bites;
  hasChanges = true;
}
```

**Result:** Now matches the pattern used for other fields and correctly propagates empty states to all consumers.

---

**Last Updated:** November 11, 2025
**Status:** ✅ **COMPLETE** - All interconnected parameters are now properly linked!

