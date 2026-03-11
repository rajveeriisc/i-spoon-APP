import jwt from "jsonwebtoken";
import dotenv from "dotenv";
import { SECURITY_CONFIG } from "./src/config/security.js";
dotenv.config();

const payload = {
  id: 1,
  email: "test@example.com"
};

const token = jwt.sign(payload, process.env.JWT_SECRET || 'fallback_secret', {
  issuer: SECURITY_CONFIG.JWT.ISSUER,
  audience: SECURITY_CONFIG.JWT.AUDIENCE,
  expiresIn: "1h"
});

console.log(token);
