import fetch from "node-fetch";

// Sends a password reset email via Firebase Auth's built-in email service
// Requires FIREBASE_WEB_API_KEY in environment (Web API key from Firebase project settings)
export async function sendFirebasePasswordResetEmail(email) {
  if (typeof email !== "string" || email.trim().length === 0) {
    throw new Error("Email is required");
  }
  const apiKey = process.env.FIREBASE_WEB_API_KEY;
  if (!apiKey) {
    throw new Error("FIREBASE_WEB_API_KEY is required to send Firebase emails");
  }

  const continueUrl = process.env.APP_BASE_URL || "http://localhost:5000";
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${encodeURIComponent(apiKey)}`;
  const body = {
    requestType: "PASSWORD_RESET",
    email,
    continueUrl,
  };

  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    const msg = data?.error?.message || "Failed to send password reset email";
    throw new Error(msg);
  }
  return data;
}

// Sends an email verification via Firebase Auth for the currently signed-in user
// Requires FIREBASE_WEB_API_KEY and a valid Firebase ID token from the client
export async function sendFirebaseVerificationEmail(idToken) {
  if (typeof idToken !== "string" || idToken.trim().length === 0) {
    throw new Error("idToken is required");
  }
  const apiKey = process.env.FIREBASE_WEB_API_KEY;
  if (!apiKey) {
    throw new Error("FIREBASE_WEB_API_KEY is required to send Firebase emails");
  }

  const continueUrl = process.env.APP_BASE_URL || "http://localhost:5000";
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${encodeURIComponent(apiKey)}`;
  const body = {
    requestType: "VERIFY_EMAIL",
    idToken,
    continueUrl,
  };

  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    const msg = data?.error?.message || "Failed to send verification email";
    throw new Error(msg);
  }
  return data;
}


