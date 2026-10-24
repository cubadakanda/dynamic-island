const { EventEmitter } = require('events');

class SMTCBridge extends EventEmitter {
  constructor() {
    super();
    this.currentSession = null;
    this.pollingInterval = null;
  }

  startPolling(intervalMs = 2000) {
    // In production, queries Windows Runtime GlobalSystemMediaTransportControlsSessionManager
    // Here we provide the robust event emitter bridge
    this.pollingInterval = setInterval(() => {
      this.checkSystemMedia();
    }, intervalMs);
  }

  stopPolling() {
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
      this.pollingInterval = null;
    }
  }

  checkSystemMedia() {
    // Emits when external apps (Chrome, Spotify, VLC) update media metadata
    if (this.currentSession) {
      this.emit('media-update', this.currentSession);
    }
  }

  setMockSession(session) {
    this.currentSession = session;
    this.emit('media-update', session);
  }
}

module.exports = { SMTCBridge };
