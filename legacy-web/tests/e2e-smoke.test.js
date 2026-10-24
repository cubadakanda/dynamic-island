const assert = require('assert');
const { createAppState } = require('../src/app');

const app = createAppState();
assert.strictEqual(typeof app.init, 'function', 'app should have init function');
assert.strictEqual(typeof app.shutdown, 'function', 'app should have shutdown function');
assert.strictEqual(typeof app.getComponents, 'function', 'app should expose components');

const comps = app.getComponents();
assert.ok(comps.windowManager, 'WindowManager is registered');
assert.ok(comps.shelfEngine, 'ShelfEngine is registered');
assert.ok(comps.pomodoroEngine, 'PomodoroEngine is registered');
assert.ok(comps.smtcBridge, 'SMTCBridge is registered');
assert.ok(comps.systemMonitor, 'SystemMonitor is registered');

console.log('e2e component wiring test passed');
