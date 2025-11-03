const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Send notification when a new contribution is added
exports.onContributionCreated = functions.firestore
  .document('households/{householdId}/contributions/{contributionId}')
  .onCreate(async (snap, context) => {
    try {
      console.log('🔔 [Contribution] Trigger iniciado');
      const contribution = snap.data();
      const householdId = context.params.householdId;
      console.log('🔔 [Contribution] householdId:', householdId);
      console.log('🔔 [Contribution] contributionId:', context.params.contributionId);
      console.log('🔔 [Contribution] Datos:', JSON.stringify(contribution));

      // Get household members
      console.log('🔔 [Contribution] Obteniendo miembros del household...');
      const membersSnapshot = await admin
        .firestore()
        .collection('households')
        .doc(householdId)
        .collection('members')
        .get();

      console.log('🔔 [Contribution] Total de miembros:', membersSnapshot.size);

      // Get all FCM tokens except the contributor
      const tokens = [];
      membersSnapshot.forEach((doc) => {
        const member = doc.data();
        console.log('🔔 [Contribution] Miembro:', member.displayName, 'UID:', member.uid);
        console.log('🔔 [Contribution] FCM Tokens:', member.fcmTokens);
        
        if (member.uid !== contribution.by && member.fcmTokens) {
          console.log('🔔 [Contribution] Agregando tokens de:', member.displayName);
          tokens.push(...member.fcmTokens);
        } else if (member.uid === contribution.by) {
          console.log('🔔 [Contribution] Saltando contribuidor:', member.displayName);
        } else {
          console.log('⚠️ [Contribution] Miembro sin tokens:', member.displayName);
        }
      });

      console.log('🔔 [Contribution] Total de tokens recopilados:', tokens.length);
      console.log('🔔 [Contribution] Tokens:', JSON.stringify(tokens));

      if (tokens.length === 0) {
        console.log('⚠️ [Contribution] No hay tokens para enviar notificaciones');
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

      console.log('🔔 [Contribution] Enviando notificaciones a', tokens.length, 'tokens...');
      
      // Enviar notificación a cada token individualmente (más confiable)
      const sendPromises = tokens.map(token => {
        return admin.messaging().send({
          notification: message.notification,
          data: message.data,
          token: token,
        }).then(() => {
          console.log('✅ [Contribution] Notificación enviada a token:', token.substring(0, 20) + '...');
          return { success: true };
        }).catch((error) => {
          console.error('❌ [Contribution] Error enviando a token:', token.substring(0, 20) + '...', error.message);
          return { success: false, error };
        });
      });
      
      const results = await Promise.all(sendPromises);
      const successCount = results.filter(r => r.success).length;
      const failureCount = results.filter(r => !r.success).length;
      
      console.log('✅ [Contribution] Total éxitos:', successCount);
      console.log('❌ [Contribution] Total fallos:', failureCount);
      
      return { successCount, failureCount };
    } catch (error) {
      console.error('❌ [Contribution] Error general:', error);
      console.error('❌ [Contribution] Stack:', error.stack);
      return null;
    }
  });

// Send notification when a new expense is added
exports.onExpenseCreated = functions.firestore
  .document('households/{householdId}/expenses/{expenseId}')
  .onCreate(async (snap, context) => {
    try {
      console.log('🔔 [Expense] Trigger iniciado');
      const expense = snap.data();
      const householdId = context.params.householdId;
      console.log('🔔 [Expense] householdId:', householdId);
      console.log('🔔 [Expense] expenseId:', context.params.expenseId);
      console.log('🔔 [Expense] Datos:', JSON.stringify(expense));

      // Get household members
      console.log('🔔 [Expense] Obteniendo miembros del household...');
      const membersSnapshot = await admin
        .firestore()
        .collection('households')
        .doc(householdId)
        .collection('members')
        .get();

      console.log('🔔 [Expense] Total de miembros:', membersSnapshot.size);

      // Get all FCM tokens except the spender
      const tokens = [];
      membersSnapshot.forEach((doc) => {
        const member = doc.data();
        console.log('🔔 [Expense] Miembro:', member.displayName, 'UID:', member.uid);
        console.log('🔔 [Expense] FCM Tokens:', member.fcmTokens);
        
        if (member.uid !== expense.by && member.fcmTokens) {
          console.log('🔔 [Expense] Agregando tokens de:', member.displayName);
          tokens.push(...member.fcmTokens);
        } else if (member.uid === expense.by) {
          console.log('🔔 [Expense] Saltando quien gastó:', member.displayName);
        } else {
          console.log('⚠️ [Expense] Miembro sin tokens:', member.displayName);
        }
      });

      console.log('🔔 [Expense] Total de tokens recopilados:', tokens.length);
      console.log('🔔 [Expense] Tokens:', JSON.stringify(tokens));

      if (tokens.length === 0) {
        console.log('⚠️ [Expense] No hay tokens para enviar notificaciones');
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

      console.log('🔔 [Expense] Enviando notificaciones a', tokens.length, 'tokens...');
      
      // Enviar notificación a cada token individualmente (más confiable)
      const sendPromises = tokens.map(token => {
        return admin.messaging().send({
          notification: message.notification,
          data: message.data,
          token: token,
        }).then(() => {
          console.log('✅ [Expense] Notificación enviada a token:', token.substring(0, 20) + '...');
          return { success: true };
        }).catch((error) => {
          console.error('❌ [Expense] Error enviando a token:', token.substring(0, 20) + '...', error.message);
          return { success: false, error };
        });
      });
      
      const results = await Promise.all(sendPromises);
      const successCount = results.filter(r => r.success).length;
      const failureCount = results.filter(r => !r.success).length;
      
      console.log('✅ [Expense] Total éxitos:', successCount);
      console.log('❌ [Expense] Total fallos:', failureCount);
      
      return { successCount, failureCount };
    } catch (error) {
      console.error('❌ [Expense] Error general:', error);
      console.error('❌ [Expense] Stack:', error.stack);
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

      // Enviar notificación a cada token individualmente
      const sendPromises = tokens.map(token => {
        return admin.messaging().send({
          notification: message.notification,
          data: message.data,
          token: token,
        }).then(() => ({ success: true }))
          .catch((error) => {
            console.error('Error sending to token:', error.message);
            return { success: false, error };
          });
      });
      
      const results = await Promise.all(sendPromises);
      const successCount = results.filter(r => r.success).length;
      
      console.log('Successfully sent month closure notification. Success:', successCount);
      return { success: true, sentCount: successCount };
    } catch (error) {
      console.error('Error sending month closure notification:', error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  }
);
