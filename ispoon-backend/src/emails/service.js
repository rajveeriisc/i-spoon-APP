import dotenv from "dotenv";
import { Resend } from "resend";
import { renderWelcomeEmail } from "./templates/welcome.js";
import { renderResetPasswordEmail } from "./templates/resetPassword.js";

dotenv.config();

const resendApiKey = process.env.RESEND_API_KEY;
const defaultFrom = process.env.EMAIL_FROM || "SmartSpoon <onboarding@resend.dev>";
const appName = process.env.APP_NAME || "SmartSpoon";
const nodeEnv = (process.env.NODE_ENV || "development").toLowerCase();

let resendClient = null;
if (resendApiKey) {
  resendClient = new Resend(resendApiKey);
}

export async function sendEmail({ to, subject, text, html }) {
  const from = defaultFrom;

  if (!resendClient) {
    console.log("📧 (DEV) Email:", { to, subject, text, html });
    return { id: "dev-log" };
  }

  try {
    const payload = {
      from,
      to: Array.isArray(to) ? to : [to],
      subject,
      html,
    };
    if (text) payload.text = text;

    const result = await resendClient.emails.send(payload);

    if (result?.error) {
      throw new Error(result.error.message || "Failed to send email via Resend");
    }

    return { id: result?.data?.id || "unknown" };
  } catch (err) {
    const message = String(err?.message || err || "").toLowerCase();
    const domainUnverified = message.includes("domain is not verified") || message.includes("not verified");

    if (domainUnverified) {
      if (nodeEnv === "production") {
        // In production we should not silently fallback to sandbox; require proper domain setup
        const helpful =
          "Resend domain not verified or FROM address not allowed. Set EMAIL_FROM to your verified domain and complete DNS setup in Resend. Fallback to onboarding@resend.dev is disabled in production.";
        console.error("📧 Email send blocked (production):", helpful);
        throw new Error(helpful);
      }

      // In development, allow a sandbox retry and make it obvious in logs that delivery is limited
      const sandboxFrom = "SmartSpoon <onboarding@resend.dev>";
      console.warn(
        "📧 Using Resend sandbox sender in development; delivery is limited to verified recipients.",
        { originalFrom: from, sandboxFrom }
      );
      const retryPayload = {
        from: sandboxFrom,
        to: Array.isArray(to) ? to : [to],
        subject,
        html,
      };
      if (text) retryPayload.text = text;
      const retry = await resendClient.emails.send(retryPayload);
      if (retry?.error) {
        throw new Error(retry.error.message || "Failed to send email via Resend (sandbox retry)");
      }
      return { id: retry?.data?.id || "unknown" };
    }

    throw err;
  }
}

export function buildResetPasswordUrl(token) {
  const appBase = process.env.APP_BASE_URL || "http://localhost:5000";
  const url = new URL("/reset-password", appBase);
  url.searchParams.set("token", token);
  return url.toString();
}

export async function sendWelcomeEmail({ to, name = null }) {
  const { subject, text, html } = renderWelcomeEmail({ name, appName });
  return sendEmail({ to, subject, text, html });
}

export async function sendPasswordResetEmail({ to, resetUrl }) {
  const { subject, text, html } = renderResetPasswordEmail({ resetUrl, appName });
  return sendEmail({ to, subject, text, html });
}


