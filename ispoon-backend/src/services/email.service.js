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
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f9fafb;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f9fafb; padding: 40px 20px;">
    <tr>
      <td align="center">
        <!-- Main Container -->
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 20px; box-shadow: 0 10px 25px rgba(0,0,0,0.05); overflow: hidden; border: 1px solid #f3f4f6;">
          
          <!-- Modern Minimal Header -->
          <tr>
            <td style="padding: 40px 40px 20px 40px; text-align: center;">
              <div style="display: inline-block; background: linear-gradient(135deg, #10b981 0%, #059669 100%); width: 64px; height: 64px; border-radius: 16px; line-height: 64px; font-size: 32px; box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3); margin-bottom: 20px;">
                🥄
              </div>
              <h1 style="margin: 0; color: #111827; font-size: 28px; font-weight: 700; letter-spacing: -0.5px;">
                Welcome to SmartSpoon
              </h1>
            </td>
          </tr>

          <!-- Main Content -->
          <tr>
            <td style="padding: 10px 45px 40px 45px;">
              <h2 style="margin: 0 0 24px 0; color: #374151; font-size: 20px; font-weight: 600;">
                Hi ${userName},
              </h2>
              
              <p style="margin: 0 0 24px 0; color: #4b5563; font-size: 16px; line-height: 1.6;">
                We're excited to be part of your journey! Your account has been verified, and you're all set to begin building healthier eating habits.
              </p>

              <p style="margin: 0 0 32px 0; color: #4b5563; font-size: 16px; line-height: 1.6;">
                SmartSpoon seamlessly tracks your eating pace, categorizes your meals, and helps you analyze tremor stability—all guided by a clean, unified dashboard.
              </p>

              <!-- Premium Features Section -->
              <div style="background-color: #f3f4f6; border-radius: 16px; padding: 30px; margin-bottom: 32px;">
                <h3 style="margin: 0 0 20px 0; color: #111827; font-size: 16px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;">
                  What's Next
                </h3>
                
                <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 16px;">
                  <tr>
                    <td width="30" valign="top" style="font-size: 20px;">📊</td>
                    <td style="padding-left: 12px;">
                      <strong style="color: #111827; font-size: 15px;">Monitor Your Pace</strong>
                      <p style="margin: 4px 0 0 0; color: #6b7280; font-size: 14px; line-height: 1.5;">Understand your eating speed and get real-time metrics.</p>
                    </td>
                  </tr>
                </table>

                <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 16px;">
                  <tr>
                    <td width="30" valign="top" style="font-size: 20px;">📱</td>
                    <td style="padding-left: 12px;">
                      <strong style="color: #111827; font-size: 15px;">Connect Your Device</strong>
                      <p style="margin: 4px 0 0 0; color: #6b7280; font-size: 14px; line-height: 1.5;">Pair your SmartSpoon via Bluetooth for instant hardware sync.</p>
                    </td>
                  </tr>
                </table>

                <table width="100%" cellpadding="0" cellspacing="0">
                  <tr>
                    <td width="30" valign="top" style="font-size: 20px;">📈</td>
                    <td style="padding-left: 12px;">
                      <strong style="color: #111827; font-size: 15px;">Review Analytics</strong>
                      <p style="margin: 4px 0 0 0; color: #6b7280; font-size: 14px; line-height: 1.5;">Discover trends and patterns in your wellness dashboard.</p>
                    </td>
                  </tr>
                </table>
              </div>

              <!-- Primary CTA -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding: 10px 0 30px 0;">
                    <a href="https://smartspoon.app" border="0"
                       style="display: inline-block; background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: #ffffff; text-decoration: none; padding: 16px 48px; border-radius: 30px; font-size: 16px; font-weight: 600; box-shadow: 0 4px 14px rgba(16, 185, 129, 0.4);">
                      Open SmartSpoon
                    </a>
                  </td>
                </tr>
              </table>

              <!-- Need Help Section -->
              <div style="border-top: 1px solid #e5e7eb; padding-top: 24px; margin-top: 10px;">
                <p style="margin: 0; color: #6b7280; font-size: 14px; line-height: 1.6; text-align: center;">
                  Questions? Reply directly to this email or visit our 
                  <a href="https://smartspoon.app/support" style="color: #10b981; text-decoration: underline; font-weight: 500;">Support Center</a>.
                </p>
              </div>
            </td>
          </tr>

          <!-- Minimal Footer -->
          <tr>
            <td style="background-color: #f9fafb; padding: 24px 30px; text-align: center;">
              <p style="margin: 0 0 6px 0; color: #9ca3af; font-size: 12px;">
                © ${new Date().getFullYear()} SmartSpoon Inc.
              </p>
              <p style="margin: 0; color: #9ca3af; font-size: 12px;">
                You received this email because you recently signed up for SmartSpoon.
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
 * Send Email Verification Email
 * 
 * Sends the Firebase-generated verification link to the user.
 * Called by firebaseAuthController when user requests email verification.
 * 
 * @param {Object} options
 * @param {string} options.email - User's email address
 * @param {string} options.verificationLink - Firebase-generated verification URL
 * @returns {Promise<Object>} - Resend API response
 */
export async function sendVerificationEmail({ email, verificationLink }) {
  try {
    if (!email) {
      throw new Error('Email is required');
    }

    const userName = email.split('@')[0];

    const htmlContent = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Verify Your Email - SmartSpoon</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f9fafb;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f9fafb; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 20px; box-shadow: 0 10px 25px rgba(0,0,0,0.05); overflow: hidden; border: 1px solid #f3f4f6;">
          <tr>
            <td style="padding: 40px 40px 20px 40px; text-align: center;">
              <div style="display: inline-block; background: linear-gradient(135deg, #10b981 0%, #059669 100%); width: 64px; height: 64px; border-radius: 16px; line-height: 64px; font-size: 32px; box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3); margin-bottom: 20px;">
                ✉️
              </div>
              <h1 style="margin: 0; color: #111827; font-size: 28px; font-weight: 700; letter-spacing: -0.5px;">
                Verify Your Email
              </h1>
            </td>
          </tr>
          <tr>
            <td style="padding: 10px 45px 40px 45px;">
              <h2 style="margin: 0 0 24px 0; color: #374151; font-size: 20px; font-weight: 600;">Hi ${userName},</h2>
              <p style="margin: 0 0 24px 0; color: #4b5563; font-size: 16px; line-height: 1.6;">
                Almost there! Please verify your email address to complete your registration and activate your SmartSpoon account.
              </p>
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding: 30px 0;">
                    <a href="${verificationLink}" style="display: inline-block; background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: #ffffff; text-decoration: none; padding: 16px 48px; border-radius: 30px; font-size: 16px; font-weight: 600; box-shadow: 0 4px 14px rgba(16, 185, 129, 0.4);">
                      Verify Account
                    </a>
                  </td>
                </tr>
              </table>
              <p style="margin: 20px 0 0 0; color: #9ca3af; font-size: 13px; text-align: center;">
                If you didn't create a SmartSpoon account, you can safely ignore this exact email.
              </p>
            </td>
          </tr>
          <tr>
            <td style="background-color: #f9fafb; padding: 24px 30px; text-align: center; border-top: 1px solid #f3f4f6;">
              <p style="margin: 0; color: #9ca3af; font-size: 12px;">© ${new Date().getFullYear()} SmartSpoon. All rights reserved.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`.trim();

    const textContent = `Verify your email for SmartSpoon\n\nHi ${userName},\n\nPlease click the link below to verify your email:\n${verificationLink}\n\nIf you didn't create an account, you can ignore this email.`;

    const { data, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to: email,
      subject: 'Verify your email - SmartSpoon 🥄',
      html: htmlContent,
      text: textContent,
    });

    if (error) {
      console.error('❌ Resend API error (verification):', error);
      throw new Error(`Failed to send verification email: ${error.message}`);
    }

    console.log(`✅ Verification email sent to ${email}`, data);
    return data;
  } catch (error) {
    console.error('❌ Failed to send verification email:', error);
    throw error;
  }
}
