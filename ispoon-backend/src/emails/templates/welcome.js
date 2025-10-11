export function renderWelcomeEmail({ name = null, appName = "SmartSpoon" } = {}) {
  const safeName = typeof name === "string" && name.trim().length > 0 ? name.trim() : "there";
  const subject = `Welcome to ${appName}!`;
  const text = `Hi ${safeName},\n\nThanks for signing up for ${appName}. We're excited to have you on board!\n\nIf you have any questions, just reply to this email.\n\n— The ${appName} Team`;
  const html = `
    <div style="font-family: system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #111">
      <h2 style="margin: 0 0 16px;">Welcome to ${appName}!</h2>
      <p style="margin: 0 0 12px;">Hi ${safeName},</p>
      <p style="margin: 0 0 12px;">Thanks for signing up for ${appName}. We're excited to have you on board!</p>
      <p style="margin: 0 0 12px;">If you have any questions, just reply to this email.</p>
      <p style="margin: 24px 0 0;">— The ${appName} Team</p>
    </div>
  `;
  return { subject, text, html };
}


