const path = require('path');
const { WindowManager } = require('./window-manager');
const { ShelfEngine } = require('./shelf-engine');
const { PomodoroEngine } = require('./pomodoro-engine');
const { SMTCBridge } = require('./smtc-monitor');
const { SystemMonitor } = require('./system-monitor');

function createAppState(options = {}) {
  const windowManager = new WindowManager(options);
  const shelfEngine = new ShelfEngine();
  const pomodoroEngine = new PomodoroEngine();
  const smtcBridge = new SMTCBridge();
  const systemMonitor = new SystemMonitor();

  let isInitialized = false;

  async function init() {
    if (isInitialized) return;
    const publicDir = path.join(__dirname, '..', 'public');
    const url = await windowManager.startServer(publicDir);
    systemMonitor.start();
    smtcBridge.startPolling();
    isInitialized = true;
    return { url };
  }

  function shutdown() {
    if (!isInitialized) return;
    windowManager.stopServer();
    systemMonitor.stop();
    smtcBridge.stopPolling();
    isInitialized = false;
  }

  function getComponents() {
    return {
      windowManager,
      shelfEngine,
      pomodoroEngine,
      smtcBridge,
      systemMonitor
    };
  }

  return {
    init,
    shutdown,
    getComponents
  };
}

module.exports = { createAppState };
