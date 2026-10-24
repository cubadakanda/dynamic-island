const assert = require('assert');
const { formatClock, isValidTab } = require('../public/js/notch-controller');

assert.strictEqual(isValidTab('shelf'), true, 'shelf should be valid');
assert.strictEqual(isValidTab('music'), true, 'music should be valid');
assert.strictEqual(isValidTab('pomodoro'), true, 'pomodoro should be valid');
assert.strictEqual(isValidTab('invalid'), false, 'invalid tab should be rejected');

const testDate = new Date('2026-10-24T19:21:00');
assert.strictEqual(formatClock(testDate), '19:21', 'Clock formatting should match HH:mm');

console.log('notch-controller logic tests passed');
