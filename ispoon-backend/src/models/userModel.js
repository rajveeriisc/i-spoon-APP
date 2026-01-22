import { pool } from "../config/db.js";

// 🔹 Find user by ID
export const getUserById = async (id) => {
  const res = await pool.query("SELECT * FROM users WHERE id=$1", [id]);
  return res.rows[0];
};

// 🔹 Find user by email
export const getUserByEmail = async (email) => {
  const normalizedEmail = email.toLowerCase();
  const res = await pool.query("SELECT * FROM users WHERE email=$1", [normalizedEmail]);
  return res.rows[0];
};

// 🔹 Update user profile
export const updateUserProfile = async (id, fields) => {
  const allowed = [
    "name",
    "phone",
    "location",
    "daily_goal",
    "notifications_enabled",
    "avatar_url",
    "profile_metadata",
  ];

  const setClauses = [];
  const values = [];

  const coerceStringOrNull = (v) => {
    if (typeof v === "string") {
      const t = v.trim();
      return t.length ? t : null;
    }
    return v == null ? null : v;
  };

  for (const key of allowed) {
    if (Object.prototype.hasOwnProperty.call(fields, key)) {
      let value = fields[key];
      if (
        [
          "name",
          "phone",
          "location",
          "avatar_url",
        ].includes(key)
      ) {
        value = coerceStringOrNull(value);
      }
      if (key === "daily_goal") {
        value = typeof value === "number" ? Math.round(value) : null;
      }
      if (key === "notifications_enabled") {
        value = typeof value === "boolean" ? value : null;
      }
      if (key === "profile_metadata") {
        value = typeof value === "object" ? JSON.stringify(value) : null;
      }

      setClauses.push(`${key}=$${values.length + 1}`);
      values.push(value);
    }
  }

  if (setClauses.length === 0) {
    const res = await pool.query(
      `SELECT id, email, name, phone, location, daily_goal, notifications_enabled, avatar_url FROM users WHERE id=$1`,
      [id]
    );
    return res.rows[0];
  }

  setClauses.push(`updated_at=NOW()`);

  const query = `UPDATE users SET ${setClauses.join(", ")} WHERE id=$${values.length + 1
    } RETURNING id, email, name, phone, location, daily_goal, notifications_enabled, avatar_url, profile_metadata`;
  values.push(id);

  const res = await pool.query(query, values);
  return res.rows[0];
};

// 🔹 Mark email as verified (synced from Firebase)
export const markEmailVerified = async (id) => {
  await pool.query(
    `UPDATE users SET email_verified = true, updated_at = NOW() WHERE id = $1`,
    [id]
  );
};


export const getUserProfile = async (id) => {
  const res = await pool.query(
    `SELECT 
      id, email, name, phone, location, daily_goal, notifications_enabled, avatar_url,
      profile_metadata, created_at, updated_at
    FROM users WHERE id = $1`,
    [id]
  );
  return res.rows[0];
};