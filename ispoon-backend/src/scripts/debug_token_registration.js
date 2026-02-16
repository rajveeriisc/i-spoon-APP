import { updateUserPreferences, getUserPreferences } from '../models/notificationModel.js';
import { pool } from '../config/db.js';

const runDebug = async () => {
    try {
        console.log("Starting debug...");
        const userId = 41; // Using user 41 (rvcelish@gmail.com)
        const testToken = "DEBUG_TOKEN_" + Date.now();

        console.log(`Attempting to update token for user ${userId} to ${testToken}`);

        // Call the model function directly
        const result = await updateUserPreferences(userId, { fcm_token: testToken });
        console.log("Update Result:", result);

        // Verify peristence
        const prefs = await getUserPreferences(userId);
        console.log("Fetched Prefs:", prefs);

        if (prefs && prefs.fcm_token === testToken) {
            console.log("✅ SUCCESS: Token was saved correctly via Model.");
        } else {
            console.log("❌ FAILURE: Token was NOT saved.");
        }

    } catch (error) {
        console.error("Debug Error:", error);
    } finally {
        pool.end();
    }
};

runDebug();
