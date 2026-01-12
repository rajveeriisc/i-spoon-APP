import { pool } from "../config/db.js";

/**
 * Helper for inserting raw payloads when we need to persist original MCU frames.
 */
export const insertRawPayload = async ({ source = null, payload = null }) => {
  const result = await pool.query(
    `
      INSERT INTO raw_payloads (source, payload)
      VALUES ($1, $2)
      RETURNING *
    `,
    [source, payload]
  );
  return result.rows[0];
};

export const insertImuSamples = async ({ deviceSessionId, samples }) => {
  if (!Array.isArray(samples) || samples.length === 0) {
    return [];
  }

  const values = [];
  const params = [];
  let paramIndex = 1;

  for (const sample of samples) {
    values.push(
      `($${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++})`
    );
    params.push(
      deviceSessionId,
      sample.recordedAt ?? null,
      sample.accelX ?? null,
      sample.accelY ?? null,
      sample.accelZ ?? null,
      sample.gyroX ?? null,
      sample.gyroY ?? null,
      sample.gyroZ ?? null,
      sample.temperatureC ?? null,
      sample.rawPayloadId ?? null
    );
  }

  const result = await pool.query(
    `
      INSERT INTO imu_samples (
        device_session_id,
        recorded_at,
        accel_x,
        accel_y,
        accel_z,
        gyro_x,
        gyro_y,
        gyro_z,
        temperature_c,
        raw_payload_id
      )
      VALUES ${values.join(", ")}
      RETURNING id, recorded_at
    `,
    params
  );

  return result.rows;
};

export const insertTemperatureSamples = async ({ deviceSessionId, samples }) => {
  if (!Array.isArray(samples) || samples.length === 0) {
    return [];
  }

  const values = [];
  const params = [];
  let paramIndex = 1;

  for (const sample of samples) {
    values.push(
      `($${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++})`
    );
    params.push(
      deviceSessionId,
      sample.recordedAt ?? null,
      sample.foodTempC ?? null,
      sample.heaterTempC ?? null,
      sample.utensilTempC ?? null
    );
  }

  const result = await pool.query(
    `
      INSERT INTO temperature_samples (
        device_session_id,
        recorded_at,
        food_temp_c,
        heater_temp_c,
        utensil_temp_c
      )
      VALUES ${values.join(", ")}
      RETURNING id, recorded_at
    `,
    params
  );

  return result.rows;
};

export const insertEnvironmentSamples = async ({ deviceSessionId, samples }) => {
  if (!Array.isArray(samples) || samples.length === 0) {
    return [];
  }

  const values = [];
  const params = [];
  let paramIndex = 1;

  for (const sample of samples) {
    values.push(
      `($${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++})`
    );
    params.push(
      deviceSessionId,
      sample.recordedAt ?? null,
      sample.ambientTempC ?? null,
      sample.humidityPercent ?? null,
      sample.pressureHpa ?? null
    );
  }

  const result = await pool.query(
    `
      INSERT INTO environment_samples (
        device_session_id,
        recorded_at,
        ambient_temp_c,
        humidity_percent,
        pressure_hpa
      )
      VALUES ${values.join(", ")}
      RETURNING id, recorded_at
    `,
    params
  );

  return result.rows;
};

export const insertTremorMetrics = async ({ deviceSessionId, metrics }) => {
  if (!Array.isArray(metrics) || metrics.length === 0) {
    return [];
  }

  const values = [];
  const params = [];
  let paramIndex = 1;

  for (const metric of metrics) {
    values.push(
      `($${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++})`
    );
    params.push(
      deviceSessionId,
      metric.recordedAt ?? null,
      metric.magnitude ?? null,
      metric.peakFrequencyHz ?? null,
      metric.level ?? null
    );
  }

  const result = await pool.query(
    `
      INSERT INTO tremor_metrics (
        device_session_id,
        recorded_at,
        magnitude,
        peak_frequency_hz,
        level
      )
      VALUES ${values.join(", ")}
      RETURNING id, recorded_at
    `,
    params
  );

  return result.rows;
};

export const insertBiteEvents = async ({ mealId, deviceSessionId = null, events }) => {
  if (!Array.isArray(events) || events.length === 0) {
    return [];
  }

  const values = [];
  const params = [];
  let paramIndex = 1;

  for (const event of events) {
    values.push(
      `($${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++})`
    );
    params.push(
      mealId,
      deviceSessionId,
      event.recordedAt ?? null,
      event.sequenceIndex,
      event.weightGrams ?? null,
      event.foodTempC ?? null,
      event.tremorMagnitude ?? null,
      event.classification ?? "valid",
      event.rawPayloadId ?? null,
      event.ingestionLatencyMs ?? null
    );
  }

  const result = await pool.query(
    `
      INSERT INTO bite_events (
        meal_id,
        device_session_id,
        recorded_at,
        sequence_index,
        weight_grams,
        food_temp_c,
        tremor_magnitude,
        classification,
        raw_payload_id,
        ingestion_latency_ms
      )
      VALUES ${values.join(", ")}
      ON CONFLICT (meal_id, sequence_index)
      DO UPDATE SET
        recorded_at = EXCLUDED.recorded_at,
        weight_grams = EXCLUDED.weight_grams,
        food_temp_c = EXCLUDED.food_temp_c,
        tremor_magnitude = EXCLUDED.tremor_magnitude,
        classification = EXCLUDED.classification,
        raw_payload_id = EXCLUDED.raw_payload_id,
        ingestion_latency_ms = EXCLUDED.ingestion_latency_ms,
        updated_at = NOW()
      RETURNING id, sequence_index
    `,
    params
  );

  return result.rows;
};

export const createMeal = async ({
  userId,
  deviceSessionId = null,
  startedAt,
  endedAt = null,
  totalBites = 0,
  avgBiteIntervalSeconds = null,
  avgBiteWeightGrams = null,
  avgFoodTempC = null,
  tremorIndex = null,
  goalTarget = null,
  anomalyCount = 0,
  notes = null,
}) => {
  const result = await pool.query(
    `
      INSERT INTO meals (
        user_id,
        device_session_id,
        started_at,
        ended_at,
        total_bites,
        avg_bite_interval_seconds,
        avg_bite_weight_grams,
        avg_food_temp_c,
        tremor_index,
        goal_target,
        anomaly_count,
        notes
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      RETURNING *
    `,
    [
      userId,
      deviceSessionId,
      startedAt,
      endedAt,
      totalBites,
      avgBiteIntervalSeconds,
      avgBiteWeightGrams,
      avgFoodTempC,
      tremorIndex,
      goalTarget,
      anomalyCount,
      notes,
    ]
  );

  return result.rows[0];
};

export const updateMealTotals = async ({
  mealId,
  totalBites = null,
  avgBiteIntervalSeconds = null,
  avgBiteWeightGrams = null,
  avgFoodTempC = null,
  tremorIndex = null,
  anomalyCount = null,
}) => {
  const result = await pool.query(
    `
      UPDATE meals
      SET
        total_bites = COALESCE($2, total_bites),
        avg_bite_interval_seconds = COALESCE($3, avg_bite_interval_seconds),
        avg_bite_weight_grams = COALESCE($4, avg_bite_weight_grams),
        avg_food_temp_c = COALESCE($5, avg_food_temp_c),
        tremor_index = COALESCE($6, tremor_index),
        anomaly_count = COALESCE($7, anomaly_count),
        updated_at = NOW()
      WHERE id = $1
      RETURNING *
    `,
    [
      mealId,
      totalBites,
      avgBiteIntervalSeconds,
      avgBiteWeightGrams,
      avgFoodTempC,
      tremorIndex,
      anomalyCount,
    ]
  );

  return result.rows[0];
};

