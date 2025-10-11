import fetch from "node-fetch";

const BASE = process.env.BASE_URL || "http://localhost:5000";

async function post(path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let data;
  try { data = JSON.parse(text); } catch { data = text; }
  return { status: res.status, data };
}

async function run() {
  const cases = [
    { name: "login missing", path: "/api/auth/login", body: {} },
    { name: "login bad email", path: "/api/auth/login", body: { email: "bad", password: "Password123!" } },
    { name: "login ok", path: "/api/auth/login", body: { email: "alice@example.com", password: "Password123!" } },
    { name: "signup weak pwd", path: "/api/auth/signup", body: { email: `new${Date.now()}@ex.com`, password: "weak" } },
    { name: "signup ok", path: "/api/auth/signup", body: { email: `ok${Date.now()}@ex.com`, password: "Password123!" } },
  ];

  for (const c of cases) {
    const res = await post(c.path, c.body);
    console.log(c.name, res.status, JSON.stringify(res.data));
  }
}

run().catch((e) => { console.error(e); process.exit(1); });


