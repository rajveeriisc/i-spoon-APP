import app from "./app.js";
import dotenv from "dotenv";
import NotificationScheduler from "./services/notificationScheduler.js";
import FCMService from "./services/fcmService.js";

dotenv.config();

const PORT = process.env.PORT || 5000;

// Async initialization
(async () => {
  // Initialize FCM Service
  try {
    await FCMService.initialize();
    console.log('✅ FCM Service initialized');
  } catch (error) {
    console.warn('⚠️  FCM Service initialization failed:', error.message);
    console.warn('   Push notifications will not be sent');
  }

  // Start notification scheduler
  NotificationScheduler.initialize();

  // Start server
  const server = app.listen(PORT, () =>
    console.log(`🚀 iSpoon Backend running on port ${PORT}`)
  );

  // Graceful shutdown
  process.on('SIGTERM', () => {
    console.log('SIGTERM signal received: closing HTTP server');
    NotificationScheduler.stopAll();
    server.close(() => {
      console.log('HTTP server closed');
    });
  });

  process.on('SIGINT', () => {
    console.log('SIGINT signal received: closing HTTP server');
    NotificationScheduler.stopAll();
    server.close(() => {
      console.log('HTTP server closed');
      process.exit(0);
    });
  });
})();