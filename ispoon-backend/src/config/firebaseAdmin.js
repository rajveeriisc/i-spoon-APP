import admin from "firebase-admin";
import fs from "fs";
import path from "path";

let initialized = false;

function normalizePrivateKey(raw) {
  if (!raw) return raw;
  let k = String(raw);
  // Strip surrounding quotes if present
  if ((k.startsWith('"') && k.endsWith('"')) || (k.startsWith("'") && k.endsWith("'"))) {
    k = k.slice(1, -1);
  }
  // Convert escaped newlines ("\n") to real newlines
  if (k.includes("\\n")) k = k.replace(/\\n/g, "\n");
  // Normalize CRLF to LF
  if (k.includes("\r\n")) k = k.replace(/\r\n/g, "\n");
  return k.trim();
}

export function getFirebaseAdmin() {
  if (initialized) return admin;

  const gac = process.env.GOOGLE_APPLICATION_CREDENTIALS;

  // Build two candidate credential sources: file first (if GAC set), then env
  const candidates = [];
  if (gac) {
    try {
      const credPath = path.isAbsolute(gac) ? gac : path.join(process.cwd(), gac);
      const json = JSON.parse(fs.readFileSync(credPath, "utf8"));
      candidates.push({
        source: "gac",
        projectId: json.project_id,
        clientEmail: json.client_email,
        privateKey: normalizePrivateKey(json.private_key),
      });
    } catch (_) {
      // ignore; fall back to env below
    }
  }
  // Fallback: look for a local serviceAccount.json next to the backend
  try {
    const localPath = path.join(process.cwd(), "serviceAccount.json");
    if (fs.existsSync(localPath)) {
      const json = JSON.parse(fs.readFileSync(localPath, "utf8"));
      candidates.push({
        source: "local",
        projectId: json.project_id,
        clientEmail: json.client_email,
        privateKey: normalizePrivateKey(json.private_key),
      });
    }
  } catch (_) {}
  candidates.push({
    source: "env",
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: normalizePrivateKey(process.env.FIREBASE_PRIVATE_KEY),
  });

  // Try candidates in order; if init fails with PEM error, try next
  let lastErr = null;
  for (const c of candidates) {
    if (!c.projectId || !c.clientEmail || !c.privateKey) {
      continue;
    }
    try {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: c.projectId,
          clientEmail: c.clientEmail,
          privateKey: c.privateKey,
        }),
      });
      initialized = true;
      return admin;
    } catch (e) {
      lastErr = e;
    }
  }

  const hint = "Check GOOGLE_APPLICATION_CREDENTIALS path or FIREBASE_PRIVATE_KEY formatting (use one line with \\n in .env).";
  throw new Error(`Firebase Admin init failed: ${lastErr?.message || "no valid credentials"}. ${hint}`);
}


