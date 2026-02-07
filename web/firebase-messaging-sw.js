importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAN41HYHixjeDVUzJqSetNgQZ2hQRPpplI',
  appId: '1:337488247760:web:16f02a0c93cad1b09197d5',
  messagingSenderId: '337488247760',
  projectId: 'osp-kolumna',
  authDomain: 'osp-kolumna.firebaseapp.com',
  storageBucket: 'osp-kolumna.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const title = notification.title || 'Powiadomienie';
  const options = {
    body: notification.body || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  };

  self.registration.showNotification(title, options);
});
