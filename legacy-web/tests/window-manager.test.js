const assert = require('assert');
const { calculateWindowBounds } = require('../src/window-manager');

const screen = { width: 1920, height: 1080, scaleFactor: 1.25 };
const collapsed = calculateWindowBounds(screen, false);
assert.strictEqual(collapsed.y, 0, 'Collapsed y should be 0');
assert.strictEqual(collapsed.width, 140, 'Collapsed width should be 140');
assert.strictEqual(collapsed.x, (1920 - 140) / 2, 'Collapsed x should be centered');

const expanded = calculateWindowBounds(screen, true);
assert.strictEqual(expanded.y, 0, 'Expanded y should be 0');
assert.strictEqual(expanded.width, 560, 'Expanded width should be 560');
assert.strictEqual(expanded.height, 190, 'Expanded height should be 190');
assert.strictEqual(expanded.x, (1920 - 560) / 2, 'Expanded x should be centered');

console.log('calculateWindowBounds passed');
