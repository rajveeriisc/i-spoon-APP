export function renderResetPasswordEmail({ resetUrl, appName = "SmartSpoon" } = {}) {
  const subject = `${appName} Password Reset`;
  const safeUrl = typeof resetUrl === "string" ? resetUrl : "";
  const text = `You requested a password reset for ${appName}.\n\nClick the link below to set a new password (valid for 1 hour):\n${safeUrl}`;
  const html = `
    <div style="font-family: system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #111">
      <h2 style="margin: 0 0 16px;">Reset your password</h2>
      <p style="margin: 0 0 12px;">You requested a password reset for ${appName}.</p>
      <p style="margin: 0 0 12px;">Click the link below to set a new password (valid for 1 hour):</p>
      <p style="margin: 0 0 12px;"><a href="${safeUrl}">${safeUrl}</a></p>
      <p style="margin: 24px 0 0; color: #555; font-size: 13px;">If you did not request this, you can safely ignore this email.</p>
    </div>
  `;
  return { subject, text, html };
}


