const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Send notification when a new contribution is added
exports.onContributionCreated = functions.firestore
  .document('households/{householdId}/contributions/{contributionId}')
  .onCreate(async (snap, context) => {
    try {
      const contribution = snap.data();
      const householdId = context.params.householdId;

      // Get household members
      const membersSnapshot = await admin
        .firestore()
        .collection('households')
        .doc(householdId)
        .collection('members')
        .get();

      // Get all FCM tokens except the contributor
      const tokens = [];
      membersSnapshot.forEach((doc) => {
        const member = doc.data();
        if (member.uid !== contribution.by && member.fcmTokens) {
          tokens.push(...member.fcmTokens);
        }
      });

      if (tokens.length === 0) {
        console.log('No tokens to send notifications to');
        return null;
      }

      // Format amount
      const amount = new Intl.NumberFormat('es-MX', {
        style: 'currency',
        currency: 'MXN',
      }).format(contribution.amount);

      // Send notification
      const message = {
        notification: {
          title: '💰 Nueva aportación',
          body: `${contribution.byDisplayName} aportó ${amount}`,
        },
        data: {
          type: 'contribution',
          householdId: householdId,
          contributionId: context.params.contributionId,
          amount: contribution.amount.toString(),
        },
        tokens: tokens,
      };

      const response = await admin.messaging().sendMulticast(message);
      console.log('Successfully sent contribution notification:', response);
      return response;
    } catch (error) {
      console.error('Error sending contribution notification:', error);
      return null;
    }
  });

// Send notification when a new expense is added
exports.onExpenseCreated = functions.firestore
  .document('households/{householdId}/expenses/{expenseId}')
  .onCreate(async (snap, context) => {
    try {
      const expense = snap.data();
      const householdId = context.params.householdId;

      // Get household members
      const membersSnapshot = await admin
        .firestore()
        .collection('households')
        .doc(householdId)
        .collection('members')
        .get();

      // Get all FCM tokens except the spender
      const tokens = [];
      membersSnapshot.forEach((doc) => {
        const member = doc.data();
        if (member.uid !== expense.by && member.fcmTokens) {
          tokens.push(...member.fcmTokens);
        }
      });

      if (tokens.length === 0) {
        console.log('No tokens to send notifications to');
        return null;
      }

      // Format amount
      const amount = new Intl.NumberFormat('es-MX', {
        style: 'currency',
        currency: 'MXN',
      }).format(expense.amount);

      // Send notification
      const message = {
        notification: {
          title: '💸 Nuevo gasto',
          body: `${expense.byDisplayName} gastó ${amount} en ${expense.categoryName}`,
        },
        data: {
          type: 'expense',
          householdId: householdId,
          expenseId: context.params.expenseId,
          categoryId: expense.categoryId,
          amount: expense.amount.toString(),
        },
        tokens: tokens,
      };

      const response = await admin.messaging().sendMulticast(message);
      console.log('Successfully sent expense notification:', response);
      return response;
    } catch (error) {
      console.error('Error sending expense notification:', error);
      return null;
    }
  });

// Send notification when month is closed
exports.sendMonthClosureNotification = functions.https.onCall(
  async (data, context) => {
    try {
      // Check authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          'unauthenticated',
          'User must be authenticated'
        );
      }

      const { householdId, month, carryOver } = data;

      // Get household members
      const membersSnapshot = await admin
        .firestore()
        .collection('households')
        .doc(householdId)
        .collection('members')
        .get();

      // Get all FCM tokens
      const tokens = [];
      membersSnapshot.forEach((doc) => {
        const member = doc.data();
        if (member.fcmTokens) {
          tokens.push(...member.fcmTokens);
        }
      });

      if (tokens.length === 0) {
        console.log('No tokens to send notifications to');
        return { success: true, sentCount: 0 };
      }

      // Format amount
      const amount = new Intl.NumberFormat('es-MX', {
        style: 'currency',
        currency: 'MXN',
      }).format(carryOver);

      // Send notification
      const message = {
        notification: {
          title: '📊 Mes cerrado',
          body: `Se cerró el mes ${month}. Saldo para el siguiente mes: ${amount}`,
        },
        data: {
          type: 'month_closure',
          householdId: householdId,
          month: month,
          carryOver: carryOver.toString(),
        },
        tokens: tokens,
      };

      const response = await admin.messaging().sendMulticast(message);
      console.log('Successfully sent month closure notification:', response);
      return { success: true, sentCount: response.successCount };
    } catch (error) {
      console.error('Error sending month closure notification:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  }
);
