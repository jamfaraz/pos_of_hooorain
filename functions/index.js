const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

const allowedStatuses = new Set(["Accepted", "Delivered", "Cancelled"]);
const forwardTransitions = new Map([
  ["Accepted", new Set(["Pending"])],
  ["Delivered", new Set(["Accepted"])],
  ["Cancelled", new Set(["Pending", "Accepted"])],
]);

function getQuantities(order) {
  const quantities = new Map();

  if (order.productQuantities && typeof order.productQuantities === "object") {
    for (const [productId, quantity] of Object.entries(order.productQuantities)) {
      const parsed = Number(quantity);
      if (productId && Number.isInteger(parsed) && parsed > 0) {
        quantities.set(productId, (quantities.get(productId) || 0) + parsed);
      }
    }
  }

  if (quantities.size === 0 && Array.isArray(order.items)) {
    for (const item of order.items) {
      const productId = String(item.productId || "");
      const quantity = Number(item.quantity ?? item.qty ?? 0);
      if (productId && Number.isInteger(quantity) && quantity > 0) {
        quantities.set(productId, (quantities.get(productId) || 0) + quantity);
      }
    }
  }

  return quantities;
}

async function requireAdmin(auth) {
  if (!auth) {
    throw new HttpsError("unauthenticated", "Sign in is required.");
  }

  const adminDoc = await db.collection("admin").doc(auth.uid).get();
  if (!adminDoc.exists) {
    throw new HttpsError("permission-denied", "Administrator access is required.");
  }
}

async function sendCustomerNotification(order, orderId, status, reason, adminUid) {
  const userId = String(order.userId || "");
  if (!userId) return;

  const userDoc = await db.collection("users").doc(userId).get();
  const user = userDoc.exists ? userDoc.data() || {} : {};
  const tokens = new Set();
  if (typeof user.fcmToken === "string" && user.fcmToken.trim()) {
    tokens.add(user.fcmToken.trim());
  }
  if (Array.isArray(user.fcmTokens)) {
    for (const token of user.fcmTokens) {
      if (typeof token === "string" && token.trim()) tokens.add(token.trim());
    }
  }
  const displayId = String(order.orderId || order.number || orderId);
  const copy = {
    Accepted: ["Order Accepted!", `Your order #${displayId} has been accepted.`],
    Delivered: ["Order Delivered!", `Your order #${displayId} was delivered.`],
    Cancelled: ["Order Cancelled", `Your order #${displayId} was cancelled.${reason ? ` ${reason}` : ""}`],
  }[status];
  if (!copy) return;

  const notificationRef = db.collection("Notifications").doc();
  await notificationRef.set({
    notificationUid: notificationRef.id,
    currentUserId: adminUid,
    userId,
    message: copy[1],
    title: copy[0],
    orderId,
    orderDocId: orderId,
    orderNumber: displayId,
    screen: "order_detail",
    status,
    isChat: false,
    isRead: false,
    time: FieldValue.serverTimestamp(),
  });

  if (tokens.size > 0) {
    await messaging.sendEachForMulticast({
      tokens: [...tokens],
      notification: {title: copy[0], body: copy[1]},
      data: {
        screen: "order_detail",
        orderId: orderId,
        orderDocId: orderId,
        orderNumber: displayId,
        status,
      },
    });
  }
}

exports.changeOrderStatus = onCall(
  {region: "us-central1", cors: true},
  async (request) => {
    await requireAdmin(request.auth);

    const orderId = String(request.data?.orderId || "").trim();
    const status = String(request.data?.status || "").trim();
    const reason = String(request.data?.reason || "").trim();
    const collection = request.data?.collection === "bills" ? "bills" : "orders";

    if (!orderId) {
      throw new HttpsError("invalid-argument", "orderId is required.");
    }
    if (!allowedStatuses.has(status)) {
      throw new HttpsError(
        "invalid-argument",
        "Status must be Accepted, Delivered, or Cancelled.",
      );
    }
    if (status === "Cancelled" && !reason) {
      throw new HttpsError(
        "invalid-argument",
        "A cancellation reason is required.",
      );
    }

    const orderRef = db.collection(collection).doc(orderId);
    let response;
    let alreadyApplied = false;

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(orderRef);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Order not found.");
      }

      const order = snapshot.data() || {};
      const currentStatus = String(order.status || "Pending").trim();
      if (currentStatus === status) {
        alreadyApplied = true;
        response = {
          success: true,
          alreadyApplied: true,
          orderId,
          status,
        };
        return;
      }

      const allowedFrom = forwardTransitions.get(status);
      if (!allowedFrom || !allowedFrom.has(currentStatus)) {
        throw new HttpsError(
          "failed-precondition",
          `Cannot change order from ${currentStatus} to ${status}.`,
        );
      }

      const update = {
        status,
        statusReason: reason || "",
        statusUpdatedAt: FieldValue.serverTimestamp(),
        statusUpdatedBy: request.auth.uid,
        updatedAt: FieldValue.serverTimestamp(),
        statusHistory: FieldValue.arrayUnion({
          status,
          reason: reason || "",
          updatedBy: request.auth.uid,
          updatedAt: new Date(),
        }),
      };

      if (status === "Cancelled" && order.stockRestored !== true) {
        const quantities = getQuantities(order);
        for (const [productId, quantity] of quantities) {
          const productRef = db.collection("products").doc(productId);
          const productSnapshot = await transaction.get(productRef);
          if (!productSnapshot.exists) continue;

          const product = productSnapshot.data() || {};
          const currentStock = Number(product.stock ?? product.totalQuantity ?? 0);
          const restoredStock = currentStock + quantity;
          transaction.update(productRef, {
            stock: restoredStock,
            totalQuantity: restoredStock,
            isOutOfStock: restoredStock <= 0,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        update.stockRestored = true;
      }

      transaction.update(orderRef, update);
      response = {
        success: true,
        alreadyApplied: false,
        orderId,
        status,
      };
    });

    if (!alreadyApplied) {
      const orderSnapshot = await orderRef.get();
      await sendCustomerNotification(
        orderSnapshot.data() || {},
        orderId,
        status,
        reason,
        request.auth.uid,
      );
    }

    return response;
  },
);
