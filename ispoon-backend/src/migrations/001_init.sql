-- Enable useful extensions
CREATE EXTENSION IF NOT EXISTS citext;

-- Users table (normalized to README spec)
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  email CITEXT UNIQUE NOT NULL,
  password TEXT, -- nullable for Firebase-only users
  name TEXT,
  phone TEXT,
  location TEXT,
  bio TEXT,
  diet_type TEXT,
  activity_level TEXT,
  allergies TEXT[],
  daily_goal INTEGER,
  notifications_enabled BOOLEAN,
  emergency_contact TEXT,
  avatar_url TEXT,
  firebase_uid VARCHAR(255) UNIQUE,
  auth_provider VARCHAR(50) DEFAULT 'email',
  email_verified BOOLEAN DEFAULT false,
  reset_token TEXT,
  reset_token_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Bites table
CREATE TABLE IF NOT EXISTS bites (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL DEFAULT 1 CHECK (amount > 0),
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bites_user_day ON bites(user_id, occurred_at);


