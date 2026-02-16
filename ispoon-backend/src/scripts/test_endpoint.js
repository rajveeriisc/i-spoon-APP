// Test FCM endpoint
import fetch from 'node-fetch';

const run = async () => {
    try {
        console.log("Testing POST /api/notifications/fcm-token...");
        const res = await fetch('http://localhost:5000/api/notifications/fcm-token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ fcm_token: "test" })
        });
        console.log(`Status: ${res.status}`);
        console.log(`Body: ${await res.text()}`);
    } catch (e) {
        console.error("Error:", e);
    }
};

run();
