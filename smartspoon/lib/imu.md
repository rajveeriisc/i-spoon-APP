Full Processing Setup

IMU-only Bite Count + Tremor Index (20-Sample Packet Based)

1. Assumptions & Inputs (Fixed)
IMU Data Input

Data arrives via BLE in chunks of 20 samples

Sampling rate: 25 Hz

20 samples ≈ 0.8 seconds of motion

Each sample contains:

timestamp
ax, ay, az   (accelerometer)
gx, gy, gz   (gyroscope)

2. High-Level Architecture
ESP32 + IMU
   ↓ BLE (20-sample packets)
Flutter Mobile App
   ├── Real-time bite detection (per packet)
   ├── Tremor feature accumulation (per packet)
   ├── Interim UI updates (optional)
   └── Final meal aggregation
        ↓
Local DB (SQLite)
        ↓ (sync)
Backend DB (PostgreSQL)


📌 All signal processing happens on the mobile device

3. Data Flow (Step-by-Step)
Step 1: BLE Packet Reception

BLE notify delivers 20 IMU samples at once

Packet is decoded into an array of IMU samples

BLE Packet → List<ImuSample> (length = 20)

4. Bite Count Processing (Continuous, Packet-Based)
When Bite Is Calculated

✅ Every time a 20-sample packet arrives

Why?

Bite detection depends on peaks + timing

You do NOT need the full meal for this

Bite Detection Logic (Per Packet)

For each 20-sample packet:

Compute acceleration magnitude

acc_mag = sqrt(ax² + ay² + az²)
linear_acc = acc_mag − 1g


Compute gyroscope magnitude

gyro_mag = sqrt(gx² + gy² + gz²)


Find:

Maximum linear acceleration in packet

Maximum gyro magnitude in packet

Apply rule:

IF:
  acc_peak > ACC_THRESHOLD
  AND gyro_peak > GYRO_THRESHOLD
  AND time_since_last_bite > 2.5 sec
THEN:
  bite_count += 1

Output (Updated Continuously)

current_bite_count

bites_per_min (optional)

📌 Bite count is final by the time meal ends

5. Tremor Processing (Accumulate First, Decide Later)
Key Design Rule

❌ Do NOT decide tremor per packet
✅ Accumulate tremor features over the whole meal

Step 5.1: Tremor Feature Extraction (Per Packet)

From each 20-sample packet:

Compute:

Gyro magnitude series

Variance

RMS (root mean square)

Store only features, NOT raw data:

PacketFeatures {
  variance,
  rms,
  timestamp
}


Append to:

mealTremorFeatureList[]


📌 This is lightweight and memory-safe.

Step 5.2: Optional Interim Tremor Display (During Meal)

If you want mid-meal indication:

Compute rolling average of last N packets (e.g. last 5 packets ≈ 4 sec)

Map to tremor scale (0–3)

Show as:

Current Tremor: Mild / Moderate


⚠️ This is informational only, not stored as final.

6. Meal Completion Trigger

Meal ends when:

User taps “End Meal”
OR

No significant motion for 5–7 minutes

At this moment:

bite_count → final
tremor_features → aggregated

7. Final Tremor Index Calculation (After Meal)
Step 7.1: Aggregate Meal Tremor Data

From mealTremorFeatureList[]:

Compute:

Average variance

Maximum variance

Average RMS

Maximum RMS

Step 7.2: Compute Tremor Index

Normalize values into 0–3 scale:

tremor_index = normalize(
  avg_variance × weight1 +
  max_variance × weight2
)


Result:

avg_tremor_index

max_tremor_index

📌 This is the only tremor data stored permanently

8. Final Meal Summary Object

This is created once per meal:

{
  "meal_id": "uuid",
  "start_time": "...",
  "end_time": "...",
  "duration_minutes": 18,
  "bite_count": 27,
  "avg_tremor_index": 1.3,
  "max_tremor_index": 2.1
}

9. Storage Strategy
On Device (SQLite)

Store one row per meal

No raw IMU data

No per-packet tremor data

Backend (PostgreSQL)

Same summarized row

Used for:

History

Trends

Reports

Doctor dashboard

10. UI Behavior (Clean & Simple)
During Meal

Live bite count

Optional “Current Tremor Level” (rolling)

After Meal

Final bite count

Final average tremor

Final max tremor

Data saved to table

11. What You Use (Tech Stack)
On Mobile

Flutter

BLE plugin

Dart math utilities

SQLite

On Backend

Node.js

PostgreSQL

Firebase (auth + notifications only)

12. Why This Setup Is Correct

✅ Packet-based (20 samples) friendly
✅ Battery efficient
✅ No over-processing
✅ Clear separation:

Real-time = bite

Post-meal = tremor

This is exactly how commercial health wearables do it.

13. Final Mental Model (Remember This)
20 samples → detect bite
Many packets → collect tremor features
Meal ends → calculate tremor index
One row → store & show