import { sendWelcomeEmail } from '../services/email.service.js';
import dotenv from 'dotenv';

dotenv.config();

async function testEmailService() {
    console.log('🧪 Testing Email Service...\n');

    // Check environment variables
    console.log('📋 Environment Check:');
    console.log('  RESEND_API_KEY:', process.env.RESEND_API_KEY ? '✅ Set' : '❌ Missing');
    console.log('  MAIL_FROM_ADDRESS:', process.env.MAIL_FROM_ADDRESS || '❌ Not set (will use default)');
    console.log('');

    if (!process.env.RESEND_API_KEY) {
        console.error('❌ RESEND_API_KEY is not set in .env file');
        console.log('\nPlease add to your .env file:');
        console.log('RESEND_API_KEY=re_your_api_key_here');
        process.exit(1);
    }

    // Test user data
    const testUser = {
        email: process.env.TEST_EMAIL || 'test@example.com',
        name: 'Test User'
    };

    console.log('📧 Sending test welcome email to:', testUser.email);
    console.log('');

    try {
        const result = await sendWelcomeEmail(testUser);

        console.log('✅ Email sent successfully!');
        console.log('📬 Email ID:', result.id);
        console.log('');
        console.log('🎉 Email service is working correctly!');
        console.log('');
        console.log('Next steps:');
        console.log('1. Check the inbox of:', testUser.email);
        console.log('2. Check spam folder if not in inbox');
        console.log('3. Verify email content and formatting');
        console.log('4. Check Resend dashboard: https://resend.com/emails');

        process.exit(0);
    } catch (error) {
        console.error('❌ Email sending failed!');
        console.error('');
        console.error('Error details:');
        console.error('  Message:', error.message);
        console.error('  Name:', error.name);

        if (error.message.includes('API key')) {
            console.error('');
            console.error('💡 Tip: Check that your RESEND_API_KEY is correct');
            console.error('   Get your API key from: https://resend.com/api-keys');
        }

        if (error.message.includes('domain')) {
            console.error('');
            console.error('💡 Tip: Verify your sender domain in Resend dashboard');
            console.error('   Or use a verified email address');
        }

        console.error('');
        console.error('Full error:', error);
        process.exit(1);
    }
}

testEmailService();
