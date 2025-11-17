import dotenv from "dotenv";
import { pool } from "../config/db.js";

dotenv.config();
async function seed() {
  try {
    const startTime = Date.now();

    const userLimit = parseInt(process.env.SEED_USER_LIMIT) || null;
    const daysToSeed = parseInt(process.env.SEED_DAYS) || 90; // 3 months default
    const minBitesPerDay = parseInt(process.env.SEED_MIN_BITES) || 30;
    const maxBitesPerDay = parseInt(process.env.SEED_MAX_BITES) || 250;
    
    console.log("🌱 Starting bite data seeding...");
    console.log(`📊 Configuration:`);
    console.log(`   - Days: ${daysToSeed}`);
    console.log(`   - Bites per day: ${minBitesPerDay}-${maxBitesPerDay}`);
    console.log(`   - User limit: ${userLimit ? userLimit + ' users' : 'all users'}`);

    const userQuery = userLimit 
      ? `SELECT id FROM users ORDER BY id ASC LIMIT $1`
      : `SELECT id FROM users ORDER BY id ASC`;
    
    const { rows: users } = userLimit 
      ? await pool.query(userQuery, [userLimit])
      : await pool.query(userQuery);
    
    if (users.length === 0) {
      console.log("⚠️  No users found in database. Please create users first.");
      return;
    }
    
    console.log(`👥 Processing ${users.length} users...`);
    
    const now = new Date();
    let totalBitesInserted = 0;
    let processedUsers = 0;
    
    // Process users in batches for better performance
    const batchSize = 10;
    for (let batchStart = 0; batchStart < users.length; batchStart += batchSize) {
      const batchEnd = Math.min(batchStart + batchSize, users.length);
      const batch = users.slice(batchStart, batchEnd);
      
      await Promise.all(batch.map(async (u) => {
        for (let d = 0; d < daysToSeed; d++) {
          const day = new Date(now.getTime() - d * 86400000);
          
          // More realistic bite distribution (bell curve around 100-150 bites)
          // Some days user might not eat (skip ~5% of days)
          if (Math.random() < 0.05) continue;
          
          // Generate random bites with realistic distribution
          const range = maxBitesPerDay - minBitesPerDay;
          const random = Math.random();
          // Bell curve: most days around middle, fewer at extremes
          const normalized = (random + Math.random() + Math.random()) / 3;
          const total = Math.floor(minBitesPerDay + (normalized * range));
          
          if (total === 0) continue;
          
          // Add realistic time distribution within the day (breakfast, lunch, dinner)
          const mealTimes = distributeBitesIntoMeals(total);
          
          for (const meal of mealTimes) {
            const mealTime = new Date(day);
            mealTime.setHours(meal.hour, meal.minute, 0, 0);
            
            await pool.query(
              `INSERT INTO bites (user_id, amount, occurred_at)
               SELECT $1, 1, $2 + (interval '1 second' * generate_series(0, $3 * 10, 10))
               ON CONFLICT DO NOTHING`,
              [u.id, mealTime, meal.bites - 1]
            );
          }
          
          totalBitesInserted += total;
        }
        processedUsers++;
      }));
      
      // Progress update
      const progress = Math.round((batchEnd / users.length) * 100);
      console.log(`   Progress: ${progress}% (${batchEnd}/${users.length} users)`);
    }
    
    const duration = ((Date.now() - startTime) / 1000).toFixed(2);
    console.log(`\n✅ Seed complete!`);
    console.log(`   - Users processed: ${processedUsers}`);
    console.log(`   - Total bites inserted: ${totalBitesInserted.toLocaleString()}`);
    console.log(`   - Average per user: ${Math.round(totalBitesInserted / processedUsers)}`);
    console.log(`   - Duration: ${duration}s`);
    
  } catch (error) {
    console.error("❌ Seed failed:", error.message);
    throw error;
  }
}



function distributeBitesIntoMeals(totalBites) {
  const meals = [];
  const mealCount = Math.random() < 0.3 ? 2 : 3; // 70% have 3 meals, 30% have 2
  
  if (mealCount === 3) {
    // Breakfast, Lunch, Dinner
    const breakfastBites = Math.floor(totalBites * (0.2 + Math.random() * 0.15)); // 20-35%
    const lunchBites = Math.floor(totalBites * (0.3 + Math.random() * 0.15));     // 30-45%
    const dinnerBites = totalBites - breakfastBites - lunchBites;                 // Remainder
    
    meals.push(
      { hour: 7 + Math.floor(Math.random() * 3), minute: Math.floor(Math.random() * 60), bites: breakfastBites },
      { hour: 12 + Math.floor(Math.random() * 2), minute: Math.floor(Math.random() * 60), bites: lunchBites },
      { hour: 18 + Math.floor(Math.random() * 3), minute: Math.floor(Math.random() * 60), bites: dinnerBites }
    );
  } else {
    // Lunch and Dinner only (skip breakfast)
    const lunchBites = Math.floor(totalBites * (0.4 + Math.random() * 0.1));     // 40-50%
    const dinnerBites = totalBites - lunchBites;                                  // Remainder
    
    meals.push(
      { hour: 12 + Math.floor(Math.random() * 2), minute: Math.floor(Math.random() * 60), bites: lunchBites },
      { hour: 18 + Math.floor(Math.random() * 3), minute: Math.floor(Math.random() * 60), bites: dinnerBites }
    );
  }
  
  return meals.filter(m => m.bites > 0);
}
seed()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(" Seed failed:", err.message);
    process.exit(1);
  });


