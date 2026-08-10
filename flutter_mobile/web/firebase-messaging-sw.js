// Firebase Cloud Messaging Service Worker for CareConnect Web
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-messaging-compat.js');

// Initialize Firebase App in Service Worker
firebase.initializeApp({
  apiKey: "mock-api-key",
  authDomain: "careconnect.firebaseapp.com",
  projectId: "careconnect",
  storageBucket: "careconnect.appspot.com",
  messagingSenderId: "100000000000",
  appId: "1:100000000000:web:mockappid"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification ? payload.notification.title : 'CareConnect SOS';
  const notificationOptions = {
    body: payload.notification ? payload.notification.body : 'Emergency alert received.',
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
