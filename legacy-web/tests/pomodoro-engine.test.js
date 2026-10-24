const assert = require('assert');
const { PomodoroEngine } = require('../src/pomodoro-engine');

const pomo = new PomodoroEngine({ focusDuration: 25 * 60, breakDuration: 5 * 60 });
assert.strictEqual(pomo.formatTime(pomo.remainingSeconds), '25:00', 'Initial time should be 25:00');

pomo.tick();
assert.strictEqual(pomo.remainingSeconds, 25 * 60 - 1, 'Tick decreases remaining time');
assert.strictEqual(pomo.formatTime(pomo.remainingSeconds), '24:59');

pomo.setMode('break');
assert.strictEqual(pomo.remainingSeconds, 5 * 60, 'Break duration should be 5:00');
assert.strictEqual(pomo.formatTime(pomo.remainingSeconds), '05:00');

pomo.reset();
assert.strictEqual(pomo.remainingSeconds, 5 * 60, 'Reset preserves active mode duration');

console.log('pomodoro-engine tests passed');
