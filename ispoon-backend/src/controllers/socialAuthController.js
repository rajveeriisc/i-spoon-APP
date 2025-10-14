import jwt from 'jsonwebtoken';
import { pool } from '../config/db.js';

const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';

export const socialLogin = async (req, res) => {
  try {
    const { provider, email, name, firebase_uid, avatar_url } = req.body;

    if (!provider || !email || !firebase_uid) {
      return res.status(400).json({
        error: 'Missing required fields: provider, email, firebase_uid',
      });
    }

    // Check if user exists
    let result = await pool.query(
      'SELECT * FROM users WHERE email = $1 OR firebase_uid = $2',
      [email, firebase_uid]
    );

    let user;

    if (result.rows.length > 0) {
      // User exists - update if needed
      user = result.rows[0];
      
      // Update firebase_uid and avatar if not set
      if (!user.firebase_uid || user.firebase_uid !== firebase_uid) {
        await pool.query(
          'UPDATE users SET firebase_uid = $1, avatar_url = $2, auth_provider = $3, updated_at = NOW() WHERE id = $4',
          [firebase_uid, avatar_url || user.avatar_url, provider, user.id]
        );
      }
    } else {
      // Create new user
      result = await pool.query(
        `INSERT INTO users (email, name, firebase_uid, avatar_url, auth_provider, email_verified, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, true, NOW(), NOW())
         RETURNING *`,
        [email, name, firebase_uid, avatar_url, provider]
      );
      user = result.rows[0];
    }

    // Generate JWT token
    const token = jwt.sign(
      { id: user.id, email: user.email },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    // Return user data
    res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        avatar_url: user.avatar_url,
        firebase_uid: user.firebase_uid,
        auth_provider: user.auth_provider,
        email_verified: user.email_verified,
        created_at: user.created_at,
      },
    });
  } catch (error) {
    console.error('Social login error:', error);
    res.status(500).json({ error: 'Server error during social login' });
  }
};

