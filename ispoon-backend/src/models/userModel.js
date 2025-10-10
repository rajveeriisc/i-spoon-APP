import { pool } from "../config/db.js";
import crypto from "crypto";

// 🔹 Create new user
export const createUser = async (email, password, name = null) => {
  const normalizedEmail = email.toLowerCase();
  const res = await pool.query(
    "INSERT INTO users (email, password, name) VALUES ($1, $2, $3) RETURNING id, email, name",
    [normalizedEmail, password, name]
  );
  return res.rows[0];
};

// 🔹 Find user by email
export const getUserByEmail = async (email) => {
  const normalizedEmail = email.toLowerCase();
  const res = await pool.query("SELECT * FROM users WHERE email=$1", [normalizedEmail]);
  return res.rows[0];
};

export const getUserById = async (id) => {
  const res = await pool.query("SELECT * FROM users WHERE id=$1", [id]);
  return res.rows[0];
};

export const updateUserProfile = async (id, fields) => {
  // Build a dynamic UPDATE that only sets provided fields. Unspecified fields remain unchanged.
  const allowed = [
    "name",
    "phone",
    "location",
    "bio",
    "diet_type",
    "activity_level",
    "allergies",
    "daily_goal",
    "notifications_enabled",
    "emergency_contact",
    "avatar_url",
  ];

  const setClauses = [];
  const values = [];

  const coerceStringOrNull = (v) => {
    if (typeof v === "string") {
      const t = v.trim();
      return t.length ? t : null; // allow clearing by sending empty string
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
          "bio",
          "diet_type",
          "activity_level",
          "emergency_contact",
          "avatar_url",
        ].includes(key)
      ) {
        value = coerceStringOrNull(value);
      }
      if (key === "allergies") {
        value = Array.isArray(value) ? value : null;
      }
      if (key === "daily_goal") {
        value = typeof value === "number" ? Math.round(value) : null;
      }
      if (key === "notifications_enabled") {
        value = typeof value === "boolean" ? value : null;
      }

      setClauses.push(`${key}=$${values.length + 1}`);
      values.push(value);
    }
  }

  // If nothing to update, just return the current row
  if (setClauses.length === 0) {
    const res = await pool.query(
      `SELECT id, email, name, phone, location, bio, diet_type, activity_level, allergies, daily_goal, notifications_enabled, emergency_contact, avatar_url FROM users WHERE id=$1`,
      [id]
    );
    return res.rows[0];
  }

  // Always bump updated_at
  setClauses.push(`updated_at=NOW()`);

  const query = `UPDATE users SET ${setClauses.join(", ")} WHERE id=$${
    values.length + 1
  } RETURNING id, email, name, phone, location, bio, diet_type, activity_level, allergies, daily_goal, notifications_enabled, emergency_contact, avatar_url`;
  values.push(id);

  const res = await pool.query(query, values);
  return res.rows[0];
};

// 🔹 Password reset helpers
export const setResetTokenForUser = async (email, token, expiresAt) => {
  const normalizedEmail = email.toLowerCase();
  const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
  await pool.query(
    `UPDATE users SET reset_token=$1, reset_token_expires_at=$2 WHERE email=$3`,
    [tokenHash, expiresAt, normalizedEmail]
  );
};

export const getUserByResetToken = async (token) => {
  const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
  const res = await pool.query(
    `SELECT * FROM users WHERE reset_token=$1 AND reset_token_expires_at > NOW()`,
    [tokenHash]
  );
  return res.rows[0];
};

export const clearResetTokenAndSetPassword = async (id, hashedPassword) => {
  await pool.query(
    `UPDATE users SET password=$1, reset_token=NULL, reset_token_expires_at=NULL, updated_at=NOW() WHERE id=$2`,
    [hashedPassword, id]
  );
};