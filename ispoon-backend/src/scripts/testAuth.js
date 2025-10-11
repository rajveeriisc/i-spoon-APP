import fetch from "node-fetch";

const BASE_URL = process.env.BASE_URL || "http://localhost:5000";

async function postJson(path, body) {
  const res = await fetch(`${BASE_URL}${path}` , {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  try {
    const json = JSON.parse(text);
    return { status: res.status, body: json };
  } catch {
    return { status: res.status, body: text };
  }
}

async function main() {
  try {
    // Test login with seeded user
    const login = await postJson("/api/auth/login", {
      email: "alice@example.com",
      password: "Password123!",
    });

    // Test signup with random user
    const random = Math.floor(Math.random() * 1_000_000);
    const signup = await postJson("/api/auth/signup", {
      email: `user${random}@example.com`,
      password: "Password123!",
    });

    console.log("LOGIN:", JSON.stringify(login));
    console.log("SIGNUP:", JSON.stringify(signup));
    process.exit(0);
  } catch (err) {
    console.error("Test failed:", err?.message || err);
    process.exit(1);
  }
}

main();


