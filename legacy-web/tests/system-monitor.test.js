const assert = require('assert');
const { ToastQueue } = require('../public/js/toast-manager');

const queue = new ToastQueue();
assert.strictEqual(queue.isEmpty(), true, 'Queue starts empty');

queue.push({ id: 'bt-1', type: 'bluetooth', title: 'Baseus Encok WM01', subtitle: 'Connected • 80%' });
assert.strictEqual(queue.isEmpty(), false, 'Queue is not empty after push');
assert.strictEqual(queue.getCurrent().title, 'Baseus Encok WM01', 'Current toast matches pushed item');

queue.dismiss();
assert.strictEqual(queue.isEmpty(), true, 'Dismiss empties the single-item queue');

console.log('system-monitor toast tests passed');
