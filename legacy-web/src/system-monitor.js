const { EventEmitter } = require('events');
const cp = require('child_process');

class SystemMonitor extends EventEmitter {
  constructor(options = {}) {
    super();
    this.pollIntervalMs = options.pollIntervalMs || 5000;
    this.timer = null;
    this.lastBluetoothState = null;
  }

  start() {
    this.checkStatus();
    this.timer = setInterval(() => {
      this.checkStatus();
    }, this.pollIntervalMs);
  }

  stop() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  checkStatus() {
    // Check Bluetooth audio devices on Windows via PowerShell
    const cmd = `powershell -NoProfile -Command "Get-PnpDevice -Class 'Bluetooth' -Status 'OK' | Select-Object -First 3 -ExpandProperty FriendlyName"`;
    cp.exec(cmd, { timeout: 4000 }, (err, stdout) => {
      if (!err && stdout) {
        const devices = stdout.trim().split(/\r?\n/).filter(Boolean);
        if (devices.length > 0) {
          const mainDevice = devices.find(d => !d.toLowerCase().includes('enumerator') && !d.toLowerCase().includes('adapter')) || devices[0];
          if (mainDevice && mainDevice !== this.lastBluetoothState) {
            this.lastBluetoothState = mainDevice;
            this.emit('bluetooth-connect', {
              name: mainDevice,
              battery: '85%'
            });
          }
        }
      }
    });
  }
}

module.exports = { SystemMonitor };
