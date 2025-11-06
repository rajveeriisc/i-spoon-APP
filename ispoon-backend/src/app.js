import express from "express";
import cors from "cors";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import cookieParser from "cookie-parser";
import crypto from "crypto";
import dotenv from "dotenv";
import authRoutes from "./modules/auth/routes.js";
import userRoutes from "./modules/users/routes.js";
import path from "path";
import { handleError, errorMiddleware } from "./utils/errorHandler.js";
import { SECURITY_CONFIG, validateSecurityConfig } from "./config/security.js";
import { pool } from "./config/db.js";
import { getFirebaseAdmin } from "./config/firebaseAdmin.js";

dotenv.config();

// Validate security configuration
try {
  validateSecurityConfig();
} catch (error) {
  console.error("❌ Security configuration error:", error.message);
  process.exit(1);
}

const app = express();
// after: const app = express();
app.set('trust proxy', 1); // trust first proxy (ngrok)
// Security headers with COOP/COEP disabled for dev (GIS popups)
app.use(helmet({
  crossOriginOpenerPolicy: false,
  crossOriginEmbedderPolicy: false,
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "https://*.googleapis.com", "https://*.firebaseio.com"],
    },
  },
}));

// CORS configuration - restrict origins for production
app.use(cors({
  origin: SECURITY_CONFIG.ALLOWED_ORIGINS,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.options("*", cors());

app.use(cookieParser());
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// Serve static uploads
app.use("/uploads", (req, res, next) => {
  res.setHeader("Cache-Control", "public, max-age=31536000, immutable");
  next();
});
app.use("/uploads", express.static(path.join(process.cwd(), "uploads")));

// Stricter rate limits for security using config
const authLimiter = rateLimit({
  ...SECURITY_CONFIG.RATE_LIMITS.AUTH,
  message: { message: 'Too many authentication attempts, please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
});

const generalLimiter = rateLimit({
  ...SECURITY_CONFIG.RATE_LIMITS.GENERAL,
  message: { message: 'Too many requests, please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
});

// Default route
app.get("/", (req, res) => {
  res.send("🥄 iSpoon Backend API Running with NeonDB & CORS ✅");
});

// CSRF token generation endpoint
app.get("/api/auth/csrf", (req, res) => {
  const token = crypto.randomBytes(32).toString('hex');
  res.cookie('csrfToken', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: 24 * 60 * 60 * 1000 // 24 hours
  });
  res.json({ csrfToken: token });
});

// Health check endpoint
app.get("/api/health", async (req, res) => {
  const health = {
    status: "ok",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    services: {
      database: "unknown",
      firebase: "unknown"
    }
  };
  
  // Check database connection
  try {
    await pool.query("SELECT 1");
    health.services.database = "ok";
  } catch (err) {
    health.services.database = "error";
    health.status = "degraded";
  }
  
  // Check Firebase Admin initialization
  try {
    const admin = getFirebaseAdmin();
    if (admin) {
      health.services.firebase = "ok";
    }
  } catch (err) {
    health.services.firebase = "error";
    health.status = "degraded";
  }
  
  res.status(health.status === "ok" ? 200 : 503).json(health);
});

// Apply general rate limiting to all routes
app.use(generalLimiter);

// Auth routes with stricter limits
app.use("/api/auth", authLimiter, authRoutes);
app.use("/api/users", userRoutes);

// Simple HTML page for resetting password from email link (dev-friendly)
app.get("/reset-password", (req, res) => {
  const token = req.query.token || "";
  const html = `<!doctype html>
  <html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Reset Password • i-Spoon</title>
    <style>
      :root{--bg:#0f172a;--card:#111827;--muted:#6b7280;--text:#e5e7eb;--primary:#6366f1;--ok:#10b981;--err:#ef4444}
      *{box-sizing:border-box}
      body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;background:linear-gradient(135deg,#0f172a,#111827);color:var(--text);}
      .wrap{min-height:100svh;display:flex;align-items:center;justify-content:center;padding:24px}
      .card{width:100%;max-width:520px;background:rgba(17,24,39,.85);backdrop-filter:blur(6px);border:1px solid rgba(255,255,255,.06);border-radius:16px;box-shadow:0 10px 30px rgba(0,0,0,.4);overflow:hidden}
      .head{padding:20px 24px;border-bottom:1px solid rgba(255,255,255,.06);display:flex;align-items:center;gap:12px}
      .logo{display:inline-flex;align-items:center;justify-content:center;width:36px;height:36px;border-radius:8px;background:linear-gradient(135deg,#6366f1,#8b5cf6)}
      .title{margin:0;font-size:18px;font-weight:700}
      .body{padding:24px}
      .desc{margin:0 0 12px;color:var(--muted);font-size:14px}
      form{display:grid;gap:14px}
      label{font-size:13px;color:var(--muted)}
      .row{display:grid;gap:8px}
      .input{display:flex;align-items:center;background:#0b1220;border:1px solid rgba(255,255,255,.08);border-radius:10px;padding:0 10px}
      .input input{flex:1;background:transparent;border:0;color:var(--text);padding:12px 8px;outline:none}
      .input button{border:0;background:transparent;color:var(--muted);cursor:pointer;padding:8px}
      .hint{font-size:12px;color:var(--muted)}
      .reqs{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:6px;margin-top:4px}
      .req{display:flex;align-items:center;gap:6px;font-size:12px;color:var(--muted)}
      .ok{color:var(--ok)}
      .err{color:var(--err)}
      .actions{margin-top:8px}
      .btn{width:100%;padding:12px 16px;border-radius:10px;border:1px solid rgba(255,255,255,.08);background:linear-gradient(135deg,#6366f1,#8b5cf6);color:white;font-weight:700;cursor:pointer}
      .btn.outline{background:transparent;border:1px solid rgba(255,255,255,.18);color:#e5e7eb}
      .btn[disabled]{opacity:.6;cursor:not-allowed}
      .alert{margin-top:10px;border-radius:10px;padding:10px 12px;font-size:14px}
      .alert.ok{background:rgba(16,185,129,.1);border:1px solid rgba(16,185,129,.35);color:#d1fae5}
      .alert.err{background:rgba(239,68,68,.1);border:1px solid rgba(239,68,68,.35);color:#fee2e2}
      .foot{padding:16px 24px;border-top:1px solid rgba(255,255,255,.06);color:var(--muted);font-size:12px}
      .token{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;color:#cbd5e1}

      /* Success view */
      .success{display:flex;flex-direction:column;align-items:center;gap:12px;text-align:center;margin-top:4px}
      .success h3{margin:6px 0 0;font-size:18px}
      .success p{margin:0;color:var(--muted);font-size:14px}
      .check{width:96px;height:96px}
      .check circle{fill:none;stroke:var(--ok);stroke-width:8;stroke-linecap:round;stroke-dasharray:314;stroke-dashoffset:314;animation:draw 900ms ease forwards}
      .check path{fill:none;stroke:var(--ok);stroke-width:8;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:100;stroke-dashoffset:100;animation:draw 600ms 500ms ease forwards}
      @keyframes draw{to{stroke-dashoffset:0}}
    </style>
  </head>
  <body>
    <div class="wrap">
      <canvas id="confetti" width="0" height="0" style="position:fixed;inset:0;pointer-events:none;z-index:100;display:none"></canvas>
      <div class="card">
        <div class="head">
          <div class="logo">🥄</div>
          <h1 class="title">Reset your password</h1>
        </div>
        <div class="body">
          <p class="desc">Create a strong password meeting all requirements below.</p>
          <form id="resetForm" method="post" action="/api/auth/reset" novalidate>
            <input type="hidden" name="token" id="token" value="${token}" />

            <div class="row">
              <label for="password">New password</label>
              <div class="input">
                <input id="password" name="password" type="password" autocomplete="new-password" placeholder="Enter new password" />
                <button type="button" id="togglePw" aria-label="Show password">👁️</button>
              </div>
              <div class="reqs" id="reqs">
                <div class="req" id="r-len">• 8+ characters</div>
                <div class="req" id="r-up">• Uppercase letter</div>
                <div class="req" id="r-low">• Lowercase letter</div>
                <div class="req" id="r-num">• Number</div>
                <div class="req" id="r-spec">• Special character</div>
              </div>
              <div class="hint">We never store your password in plain text.</div>
            </div>

            <div class="row">
              <label for="confirm">Confirm password</label>
              <div class="input">
                <input id="confirm" type="password" autocomplete="new-password" placeholder="Re-enter new password" />
                <button type="button" id="toggleC" aria-label="Show password">👁️</button>
              </div>
              <div class="hint" id="matchHint"></div>
            </div>

            <div class="actions">
              <button class="btn" id="submitBtn" type="submit">Update Password</button>
            </div>

            <div id="alert" class="alert" style="display:none"></div>
    </form>
          <div id="successView" class="success" style="display:none">
            <svg class="check" viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
              <circle cx="60" cy="60" r="50"/>
              <path d="M36 62 L54 78 L86 42"/>
            </svg>
            <h3>Password updated!</h3>
            <p>You can now close this page and log in.</p>
          <a class="btn outline" href="/">Return to i-Spoon</a>
          </div>
        </div>
        <div class="foot">
          If you are using the mobile app, open it and paste the token if needed.
          <div class="token">Token: <span id="tokenFrag"></span></div>
        </div>
      </div>
    </div>

    <script>
      (function(){
        const $ = (id)=>document.getElementById(id);
        const pw = $("password");
        const cf = $("confirm");
        const token = $("token");
        const reqs = {
          len: $("r-len"), up: $("r-up"), low: $("r-low"), num: $("r-num"), spec: $("r-spec")
        };
        const alertBox = $("alert");
        const submitBtn = $("submitBtn");

        const showHint = (el, ok) => {
          el.classList.remove('ok','err');
          el.classList.add(ok ? 'ok' : 'err');
        };
        const validate = () => {
          const v = pw.value || '';
          const checks = {
            len: v.length >= 8,
            up: /[A-Z]/.test(v),
            low: /[a-z]/.test(v),
            num: /[0-9]/.test(v),
            spec: /[^A-Za-z0-9]/.test(v),
          };
          showHint(reqs.len, checks.len);
          showHint(reqs.up, checks.up);
          showHint(reqs.low, checks.low);
          showHint(reqs.num, checks.num);
          showHint(reqs.spec, checks.spec);
          return Object.values(checks).every(Boolean);
        };
        const match = () => {
          const ok = pw.value && cf.value && pw.value === cf.value;
          const mh = $("matchHint");
          mh.textContent = ok || !cf.value ? '' : 'Passwords do not match';
          mh.style.color = ok ? 'var(--ok)' : 'var(--err)';
          return ok;
        };
        const setTokenFrag = () => {
          const t = token.value || '';
          const frag = t.length > 12 ? (t.slice(0,6) + '...' + t.slice(-6)) : t;
          $("tokenFrag").textContent = frag;
        };
        setTokenFrag();

        pw.addEventListener('input', ()=>{ validate(); match(); });
        cf.addEventListener('input', match);
        $("togglePw").addEventListener('click', ()=>{
          pw.type = pw.type === 'password' ? 'text' : 'password';
        });
        $("toggleC").addEventListener('click', ()=>{
          cf.type = cf.type === 'password' ? 'text' : 'password';
        });

        const form = document.getElementById('resetForm');
        form.addEventListener('submit', async (e)=>{
          // Keep standard POST fallback if JS fails – otherwise try fetch
          e.preventDefault();
          alertBox.style.display = 'none';
          if (!validate() || !match()) {
            alertBox.className = 'alert err';
            alertBox.textContent = 'Please meet all password requirements and confirm match.';
            alertBox.style.display = 'block';
            return;
          }
          submitBtn.disabled = true;
          try {
            const resp = await fetch('/api/auth/reset', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ token: token.value, password: pw.value })
            });
            const data = await resp.json().catch(()=>({}));
            if (resp.ok) {
              // Show animated success view
              form.style.display = 'none';
              const success = document.getElementById('successView');
              success.style.display = 'flex';
              fireConfetti();
            } else {
              throw new Error(data.message || 'Failed to update password');
            }
          } catch (err) {
            alertBox.className = 'alert err';
            alertBox.textContent = err.message || 'Something went wrong';
            alertBox.style.display = 'block';
          } finally {
            submitBtn.disabled = false;
          }
        });

        function fireConfetti(){
          const cnv = document.getElementById('confetti');
          cnv.style.display = 'block';
          const ctx = cnv.getContext('2d');
          const dpr = window.devicePixelRatio || 1;
          const resize = ()=>{ cnv.width = innerWidth * dpr; cnv.height = innerHeight * dpr; ctx.scale(dpr,dpr); };
          resize();
          let particles = Array.from({length: 150}).map(()=>({
            x: Math.random()*innerWidth,
            y: -20 + Math.random()*-innerHeight*0.2,
            r: 2 + Math.random()*4,
            c: 'hsl(' + (Math.random()*360) + ',90%,60%)',
            vx: -1+Math.random()*2,
            vy: 2+Math.random()*3,
            rot: Math.random()*Math.PI,
            vr: -0.2+Math.random()*0.4,
          }));
          const start = performance.now();
          const dur = 1500;
          (function loop(t){
            const elapsed = t - start;
            ctx.clearRect(0,0,innerWidth,innerHeight);
            particles.forEach(p=>{
              p.x += p.vx; p.y += p.vy; p.rot += p.vr; p.vy += 0.03;
              ctx.save();
              ctx.translate(p.x, p.y);
              ctx.rotate(p.rot);
              ctx.fillStyle = p.c;
              ctx.fillRect(-p.r, -p.r, p.r*2, p.r*2);
              ctx.restore();
            });
            if (elapsed < dur) requestAnimationFrame(loop); else setTimeout(()=>{ cnv.style.display='none'; ctx.clearRect(0,0,innerWidth,innerHeight); }, 250);
          })(start);
          window.addEventListener('resize', resize, { once: true });
        }
      })();
    </script>
  </body>
  </html>`;
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.send(html);
});

export default app;

// 404 handler
// eslint-disable-next-line no-unused-vars
app.use((req, res, _next) => {
  res.status(404).json({ message: 'Not Found' });
});

// Global error middleware (must be last)
app.use(errorMiddleware);