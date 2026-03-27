const functions = require("firebase-functions");
const admin = require("firebase-admin");
const Anthropic = require("@anthropic-ai/sdk");

admin.initializeApp();
const db = admin.database();

// ==================== Spoilage Alert + Recipe ====================

/**
 * Triggered whenever a device's latest reading is updated.
 * If freshness is "warning" or "spoiled", sends a push notification
 * and generates an AI recipe suggestion.
 */
exports.onReadingUpdate = functions.database
  .ref("/readings/{deviceId}")
  .onWrite(async (change, context) => {
    const data = change.after.val();
    if (!data) return null;

    const { freshness, mq135, mq3, mq9, temperature, humidity, battery } = data;
    const deviceId = context.params.deviceId;

    // Only alert on warning or spoiled
    if (freshness !== "warning" && freshness !== "spoiled") {
      return null;
    }

    // Determine what kind of spoilage is happening
    const spoilageInfo = analyzeSpoilage(mq135, mq3, mq9);

    // Send push notification (include environment context)
    await sendAlert(deviceId, freshness, spoilageInfo, { temperature, humidity, battery });

    // Generate recipe suggestion via Claude
    await generateRecipe(deviceId, freshness, spoilageInfo);

    return null;
  });

// ==================== Spoilage Analysis ====================

function analyzeSpoilage(mq135, mq3, mq9) {
  const causes = [];

  if (mq135 > 30) {
    causes.push({
      sensor: "MQ-135",
      gas: "ammonia/CO2",
      meaning: "protein breakdown in meat, fish, or dairy",
      foods: ["chicken", "beef", "fish", "milk", "cheese", "eggs"],
    });
  }

  if (mq3 > 15) {
    causes.push({
      sensor: "MQ-3",
      gas: "ethanol",
      meaning: "fermentation in fruits, vegetables, or bread",
      foods: ["fruits", "vegetables", "bread", "juice"],
    });
  }

  if (mq9 > 20) {
    causes.push({
      sensor: "MQ-9",
      gas: "methane/CO",
      meaning: "anaerobic bacterial activity in sealed food",
      foods: ["vacuum-packed meat", "canned food", "sealed leftovers"],
    });
  }

  return {
    causes,
    summary: causes.map((c) => c.meaning).join("; ") || "general spoilage detected",
    likelyFoods: [...new Set(causes.flatMap((c) => c.foods))],
  };
}

// ==================== Push Notifications ====================

async function sendAlert(deviceId, freshness, spoilageInfo, environment) {
  const title =
    freshness === "spoiled"
      ? "Food is spoiled!"
      : "Food spoilage warning";

  let body =
    freshness === "spoiled"
      ? `Detected: ${spoilageInfo.summary}. Check your fridge immediately.`
      : `Early signs: ${spoilageInfo.summary}. Use affected food soon.`;

  // Add battery warning if low
  if (environment.battery != null && environment.battery < 15) {
    body += ` (Battery: ${environment.battery}%)`;
  }

  const message = {
    topic: `device_${deviceId}`,
    notification: { title, body },
    data: {
      deviceId,
      freshness,
      spoilageInfo: JSON.stringify(spoilageInfo),
      temperature: String(environment.temperature ?? ""),
      humidity: String(environment.humidity ?? ""),
      battery: String(environment.battery ?? ""),
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: "high",
      notification: {
        channelId: "spoilage_alerts",
        priority: "max",
        defaultSound: true,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  try {
    await admin.messaging().send(message);
    console.log(`Alert sent for device ${deviceId}: ${freshness}`);

    // Store alert in database
    await db.ref(`/alerts/${deviceId}`).push({
      freshness,
      summary: spoilageInfo.summary,
      temperature: environment.temperature,
      humidity: environment.humidity,
      timestamp: admin.database.ServerValue.TIMESTAMP,
    });
  } catch (error) {
    console.error("Error sending notification:", error);
  }
}

// ==================== Low Battery Alert ====================

exports.onBatteryCheck = functions.database
  .ref("/readings/{deviceId}/battery")
  .onWrite(async (change, context) => {
    const battery = change.after.val();
    const deviceId = context.params.deviceId;

    if (battery == null || battery >= 15) return null;

    const message = {
      topic: `device_${deviceId}`,
      notification: {
        title: "Ethyleen battery low",
        body: `Battery at ${battery}%. Charge soon or readings will stop.`,
      },
      data: {
        deviceId,
        type: "battery_low",
        battery: String(battery),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };

    try {
      await admin.messaging().send(message);
    } catch (error) {
      console.error("Error sending battery alert:", error);
    }

    return null;
  });

// ==================== AI Recipe Generation ====================

async function generateRecipe(deviceId, freshness, spoilageInfo) {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    console.error("ANTHROPIC_API_KEY not set");
    return;
  }

  const client = new Anthropic({ apiKey });

  const prompt = buildRecipePrompt(freshness, spoilageInfo);

  try {
    const response = await client.messages.create({
      model: "claude-sonnet-4-6",
      max_tokens: 512,
      messages: [{ role: "user", content: prompt }],
    });

    const recipe = response.content[0].text;

    // Store recipe in database
    await db.ref(`/recipes/${deviceId}`).set({
      recipe,
      freshness,
      likelyFoods: spoilageInfo.likelyFoods,
      timestamp: admin.database.ServerValue.TIMESTAMP,
    });

    console.log(`Recipe generated for device ${deviceId}`);
  } catch (error) {
    console.error("Error generating recipe:", error);
  }
}

function buildRecipePrompt(freshness, spoilageInfo) {
  const foods = spoilageInfo.likelyFoods.join(", ");
  const urgency =
    freshness === "spoiled"
      ? "The food is already showing significant spoilage signs. Only suggest a recipe if the food might still be safe after thorough cooking. Otherwise, advise disposal."
      : "The food is showing early signs of spoilage but is still safe to eat if used soon.";

  return `You are a helpful kitchen assistant. A smart fridge sensor has detected that some food is starting to go bad.

Detected spoilage type: ${spoilageInfo.summary}
Likely affected foods: ${foods}
Urgency: ${urgency}

Suggest ONE quick recipe (under 30 minutes) that uses the affected food before it goes bad. Keep it practical — assume a basic home kitchen. Format your response as:

**Recipe name**
Time: X minutes
Ingredients: (brief list, assume the affected food + common pantry items)
Steps: (numbered, concise)

Keep the total response under 200 words.`;
}

// ==================== History Cleanup (scheduled) ====================

/**
 * Runs daily to delete history entries older than 7 days.
 */
exports.cleanupHistory = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    const cutoff = Date.now() - 7 * 24 * 60 * 60 * 1000;

    const snapshot = await db
      .ref("/history")
      .once("value");

    if (!snapshot.exists()) return null;

    const updates = {};
    snapshot.forEach((deviceSnap) => {
      deviceSnap.forEach((entrySnap) => {
        const entry = entrySnap.val();
        if (entry.timestamp && entry.timestamp < cutoff) {
          updates[`/history/${deviceSnap.key}/${entrySnap.key}`] = null;
        }
      });
    });

    if (Object.keys(updates).length > 0) {
      await db.ref().update(updates);
      console.log(`Cleaned up ${Object.keys(updates).length} old history entries`);
    }

    return null;
  });
