import * as admin from "firebase-admin";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {onCall} from "firebase-functions/v2/https";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ─── Alert Fanout ─────────────────────────────────────────────────────────────

/**
 * Triggered when a new alert is created in a group.
 * Fans out FCM notifications to all group members (except sender).
 */
export const onNewAlert = onDocumentCreated(
  "groups/{groupId}/alerts/{alertId}",
  async (event) => {
    const alert = event.data?.data();
    if (!alert) return;

    const groupId = event.params.groupId;
    const alertId = event.params.alertId;
    const isHusker = alert.type === "husker";

    console.log(
      `New ${alert.type} alert in group ${groupId} from ${alert.sentBy}`
    );

    // Get group document
    const groupDoc = await db.collection("groups").doc(groupId).get();
    if (!groupDoc.exists) return;

    const memberIds: string[] = groupDoc.data()?.memberIds ?? [];

    // Get FCM tokens for all members except sender
    const tokenPromises = memberIds
      .filter((uid: string) => uid !== alert.sentBy)
      .map(async (uid: string) => {
        const userDoc = await db.collection("users").doc(uid).get();
        return {
          uid,
          token: userDoc.data()?.fcmToken as string | undefined,
        };
      });

    const tokenResults = await Promise.all(tokenPromises);
    const validTokens = tokenResults
      .filter((r) => r.token)
      .map((r) => r.token as string);

    if (validTokens.length === 0) {
      console.log("No valid FCM tokens found");
      return;
    }

    // Build notification
    const title = isHusker
      ? `🚨 HUSKER ALERT — ${alert.senderName}`
      : `🌽 ${alert.senderName} needs a hand`;

    const body = alert.message;

    // Send multicast message
    const response = await messaging.sendEachForMulticast({
      tokens: validTokens,
      notification: {title, body},
      data: {
        type: alert.type,
        lat: String(alert.lat ?? 0),
        lng: String(alert.lng ?? 0),
        groupId,
        alertId,
        senderName: alert.senderName,
      },
      android: {
        priority: isHusker ? "high" : "normal",
        notification: {
          channelId: isHusker ? "husker_emergency" : "corn_alert",
          priority: isHusker ? "max" : "default",
          sound: isHusker ? "husker_alarm" : "corn_pop",
          notificationCount: 1,
        },
      },
      apns: {
        headers: {
          "apns-priority": isHusker ? "10" : "5",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: {title, body},
            sound: isHusker
              ? {
                  critical: 1,
                  name: "husker_alarm.wav",
                  volume: 1.0,
                }
              : "corn_pop.wav",
            "content-available": 1,
            badge: 1,
          },
        },
      },
    });

    console.log(
      `Sent ${response.successCount} / ${validTokens.length} notifications`
    );

    // Clean up failed tokens
    const failedTokens: string[] = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const error = resp.error;
        if (
          error?.code === "messaging/invalid-registration-token" ||
          error?.code === "messaging/registration-token-not-registered"
        ) {
          failedTokens.push(validTokens[idx]);
        }
      }
    });

    if (failedTokens.length > 0) {
      // Remove invalid tokens
      const batch = db.batch();
      for (const result of tokenResults) {
        if (result.token && failedTokens.includes(result.token)) {
          batch.update(db.collection("users").doc(result.uid), {
            fcmToken: admin.firestore.FieldValue.delete(),
          });
        }
      }
      await batch.commit();
    }
  }
);

// ─── Friend Request Notification ─────────────────────────────────────────────

/**
 * Notify a user when they receive a friend request.
 */
export const onNewFriendRequest = onDocumentCreated(
  "friendRequests/{requestId}",
  async (event) => {
    const request = event.data?.data();
    if (!request || request.status !== "pending") return;

    // Find the target user by username
    const usernameDoc = await db
      .collection("usernames")
      .doc(request.toUsername)
      .get();

    if (!usernameDoc.exists) return;

    const targetUid = usernameDoc.data()?.uid;
    if (!targetUid) return;

    const targetUser = await db.collection("users").doc(targetUid).get();
    const fcmToken = targetUser.data()?.fcmToken;
    if (!fcmToken) return;

    // Get sender info
    const senderDoc = await db.collection("users").doc(request.fromUid).get();
    const senderName = senderDoc.data()?.displayName ?? "Someone";
    const senderEmoji = senderDoc.data()?.avatarEmoji ?? "👤";

    await messaging.send({
      token: fcmToken,
      notification: {
        title: "New Friend Request",
        body: `${senderEmoji} ${senderName} wants to travel with you!`,
      },
      data: {
        type: "friend_request",
        requestId: event.params.requestId,
        fromUid: request.fromUid,
      },
      android: {
        priority: "normal",
        notification: {channelId: "social"},
      },
      apns: {
        headers: {"apns-priority": "5"},
        payload: {
          aps: {
            sound: "default",
            "content-available": 1,
          },
        },
      },
    });
  }
);

// ─── Friend Request Accepted Notification ────────────────────────────────────

/**
 * Notify sender when their friend request is accepted.
 */
export const onFriendRequestAccepted = onDocumentUpdated(
  "friendRequests/{requestId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) return;
    if (before.status === after.status) return;
    if (after.status !== "accepted") return;

    // Notify the original sender
    const senderDoc = await db.collection("users").doc(after.fromUid).get();
    const fcmToken = senderDoc.data()?.fcmToken;
    if (!fcmToken) return;

    // Get acceptor info
    const usernameDoc = await db
      .collection("usernames")
      .doc(after.toUsername)
      .get();
    const acceptorUid = usernameDoc.data()?.uid;
    if (!acceptorUid) return;

    const acceptorDoc = await db.collection("users").doc(acceptorUid).get();
    const acceptorName = acceptorDoc.data()?.displayName ?? after.toUsername;
    const acceptorEmoji = acceptorDoc.data()?.avatarEmoji ?? "👤";

    await messaging.send({
      token: fcmToken,
      notification: {
        title: "Friend Request Accepted! 🎉",
        body: `${acceptorEmoji} ${acceptorName} is now your travel buddy!`,
      },
      data: {
        type: "friend_accepted",
        friendUid: acceptorUid,
      },
      android: {
        priority: "normal",
        notification: {channelId: "social"},
      },
      apns: {
        headers: {"apns-priority": "5"},
      },
    });
  }
);

// ─── Cell Unlock Milestone ────────────────────────────────────────────────────

/**
 * Notify group members when someone hits a milestone.
 */
export const onTripUpdated = onDocumentUpdated(
  "users/{uid}/trips/{tripId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) return;

    const prevCount = before.totalCellsUnlocked ?? 0;
    const newCount = after.totalCellsUnlocked ?? 0;

    // Milestones: 100, 500, 1000, 5000, 10000, ...
    const milestones = [100, 500, 1000, 5000, 10000, 50000, 100000];
    const hitMilestone = milestones.find(
      (m) => prevCount < m && newCount >= m
    );

    if (!hitMilestone) return;

    const uid = event.params.uid;
    const groupId = after.groupId;
    if (!groupId) return;

    // Get user and group info
    const [userDoc, groupDoc] = await Promise.all([
      db.collection("users").doc(uid).get(),
      db.collection("groups").doc(groupId).get(),
    ]);

    const userName = userDoc.data()?.displayName ?? "A traveler";
    const userEmoji = userDoc.data()?.avatarEmoji ?? "🌽";
    const memberIds: string[] = groupDoc.data()?.memberIds ?? [];
    const percent = (hitMilestone / 550000 * 100).toFixed(2);

    // Notify all group members
    const tokenPromises = memberIds
      .filter((memberId: string) => memberId !== uid)
      .map(async (memberId: string) => {
        const doc = await db.collection("users").doc(memberId).get();
        return doc.data()?.fcmToken as string | undefined;
      });

    const tokens = (await Promise.all(tokenPromises)).filter(Boolean) as string[];
    if (tokens.length === 0) return;

    await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: "🎉 Milestone reached!",
        body: `${userEmoji} ${userName} unlocked ${hitMilestone} cells (${percent}% of France)!`,
      },
      data: {
        type: "milestone",
        cellCount: String(hitMilestone),
        uid,
      },
    });
  }
);

// ─── Callable: Update FCM Token ───────────────────────────────────────────────

export const updateFcmToken = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("Unauthenticated");
  }

  const {token} = request.data as {token: string};
  if (!token) throw new Error("Token required");

  await db.collection("users").doc(request.auth.uid).update({
    fcmToken: token,
  });

  return {success: true};
});

// ─── Callable: Resolve Alert ──────────────────────────────────────────────────

export const resolveAlert = onCall(async (request) => {
  if (!request.auth) {
    throw new Error("Unauthenticated");
  }

  const {groupId, alertId} = request.data as {
    groupId: string;
    alertId: string;
  };

  await db
    .collection("groups")
    .doc(groupId)
    .collection("alerts")
    .doc(alertId)
    .update({
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      resolvedBy: request.auth.uid,
    });

  return {success: true};
});
