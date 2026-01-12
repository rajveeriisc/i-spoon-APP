import { Resend } from 'resend';

const resend = new Resend(process.env.RESEND_API_KEY);
const FROM_EMAIL = process.env.MAIL_FROM_ADDRESS || 'noreply@smartspoon.app';

/**
 * Send Welcome Email to New Users
 * 
 * Triggered after user verifies their email address for the first time.
 * Sends a personalized welcome email with app introduction and getting started guide.
 * 
 * @param {Object} user - User object from database
 * @param {string} user.email - User's email address
 * @param {string} user.name - User's display name
 * @returns {Promise<Object>} - Resend API response
 */
export async function sendWelcomeEmail(user) {
  try {
    if (!user.email) {
      throw new Error('User email is required');
    }

    const userName = user.name || user.email.split('@')[0];

    const htmlContent = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Welcome to SmartSpoon</title>
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 40px 20px;">
    <tr>
      <td align="center">
        <!-- Main Container -->
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 16px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); overflow: hidden;">
          
          <!-- Header with Gradient -->
          <tr>
            <td style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 30px; text-align: center;">
              <h1 style="margin: 0; color: #ffffff; font-size: 32px; font-weight: 700;">
                🥄 Welcome to SmartSpoon!
              </h1>
            </td>
          </tr>

          <!-- Main Content -->
          <tr>
            <td style="padding: 40px 30px;">
              <h2 style="margin: 0 0 20px 0; color: #333333; font-size: 24px; font-weight: 600;">
                Hi ${userName}! 👋
              </h2>
              
              <p style="margin: 0 0 20px 0; color: #555555; font-size: 16px; line-height: 1.6;">
                We're thrilled to have you join the SmartSpoon community! Your account is now verified and ready to go.
              </p>

              <p style="margin: 0 0 30px 0; color: #555555; font-size: 16px; line-height: 1.6;">
                SmartSpoon is your intelligent eating companion designed to help you track meals, monitor tremors, and gain valuable insights into your eating patterns.
              </p>

              <!-- Features Section -->
              <div style="background-color: #f8f9fa; border-radius: 12px; padding: 25px; margin-bottom: 30px;">
                <h3 style="margin: 0 0 20px 0; color: #333333; font-size: 18px; font-weight: 600;">
                  🌟 What You Can Do:
                </h3>
                
                <div style="margin-bottom: 15px;">
                  <strong style="color: #667eea;">📊 Track Your Meals</strong>
                  <p style="margin: 5px 0 0 0; color: #666666; font-size: 14px;">
                    Monitor bite counts, eating pace, and meal duration in real-time
                  </p>
                </div>

                <div style="margin-bottom: 15px;">
                  <strong style="color: #667eea;">🔬 Tremor Analysis</strong>
                  <p style="margin: 5px 0 0 0; color: #666666; font-size: 14px;">
                    Get detailed tremor magnitude and frequency insights during meals
                  </p>
                </div>

                <div style="margin-bottom: 15px;">
                  <strong style="color: #667eea;">📈 Insights Dashboard</strong>
                  <p style="margin: 5px 0 0 0; color: #666666; font-size: 14px;">
                    View comprehensive analytics and trends over time
                  </p>
                </div>

                <div>
                  <strong style="color: #667eea;">🔄 Sync Across Devices</strong>
                  <p style="margin: 5px 0 0 0; color: #666666; font-size: 14px;">
                    Access your data anywhere with cloud synchronization
                  </p>
                </div>
              </div>

              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding: 20px 0;">
                    <a href="https://smartspoon.app" 
                       style="display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: #ffffff; text-decoration: none; padding: 16px 40px; border-radius: 8px; font-size: 16px; font-weight: 600; box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);">
                      Get Started Now →
                    </a>
                  </td>
                </tr>
              </table>

              <!-- Support Section -->
              <div style="border-top: 2px solid #e9ecef; padding-top: 25px; margin-top: 30px;">
                <p style="margin: 0 0 15px 0; color: #555555; font-size: 14px; line-height: 1.6;">
                  <strong>Need Help?</strong><br>
                  Our support team is here for you. Reply to this email or visit our 
                  <a href="https://smartspoon.app/support" style="color: #667eea; text-decoration: none;">Help Center</a>.
                </p>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #f8f9fa; padding: 30px; text-align: center; border-top: 1px solid #e9ecef;">
              <p style="margin: 0 0 10px 0; color: #999999; font-size: 12px;">
                © ${new Date().getFullYear()} SmartSpoon. All rights reserved.
              </p>
              <p style="margin: 0; color: #999999; font-size: 12px;">
                You're receiving this email because you created an account at SmartSpoon.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
    `.trim();

    const textContent = `
Welcome to SmartSpoon! 🥄

Hi ${userName}!

We're thrilled to have you join the SmartSpoon community! Your account is now verified and ready to go.

SmartSpoon is your intelligent eating companion designed to help you track meals, monitor tremors, and gain valuable insights into your eating patterns.

What You Can Do:

📊 Track Your Meals
Monitor bite counts, eating pace, and meal duration in real-time

🔬 Tremor Analysis
Get detailed tremor magnitude and frequency insights during meals

📈 Insights Dashboard
View comprehensive analytics and trends over time

🔄 Sync Across Devices
Access your data anywhere with cloud synchronization

Get started now: https://smartspoon.app

Need Help?
Our support team is here for you. Reply to this email or visit our Help Center at https://smartspoon.app/support

© ${new Date().getFullYear()} SmartSpoon. All rights reserved.
You're receiving this email because you created an account at SmartSpoon.
    `.trim();

    const { data, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: user.email,
      subject: 'Welcome to SmartSpoon! 🥄',
      html: htmlContent,
      text: textContent,
    });

    if (error) {
      console.error('❌ Resend API error:', error);
      throw new Error(`Failed to send email: ${error.message}`);
    }

    console.log(`✅ Welcome email sent to ${user.email}`, data);
    return data;

  } catch (error) {
    console.error('❌ Failed to send welcome email:', error);
    throw error;
  }
}

/**
 * Send Password Reset Email
 * (Placeholder for future implementation - Firebase handles this currently)
 */
export async function sendPasswordResetEmail(user, resetLink) {
  // TODO: Implement custom password reset email
  console.log('Password reset emails are handled by Firebase');
}

/**
 * Send Email Verification Reminder
 * (Placeholder for future implementation)
 */
export async function sendVerificationReminderEmail(user) {
  // TODO: Implement verification reminder email
  console.log('Email verification is handled by Firebase');
}
