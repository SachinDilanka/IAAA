// Service Worker for AcousticAware Deaf Sound Alert System
// Dispatches high-priority system notifications with strong vibration patterns to Yesido IO39 Smartwatch

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'EMERGENCY_ALERT') {
    const title = event.data.title || '🚨 EMERGENCY SOUND DETECTED!';
    const body = event.data.body || 'Immediate caution required. Check surroundings.';
    const vibratePattern = event.data.vibrate || [1000, 200, 1000, 200, 1000, 200, 1500];

    self.registration.showNotification(title, {
      body: body,
      icon: 'favicon.png',
      badge: 'favicon.png',
      vibrate: vibratePattern,
      tag: 'emergency-alert-' + Date.now(),
      renotify: true,
      requireInteraction: true,
      silent: false,
      data: {
        timestamp: Date.now(),
      },
    });
  }
});
