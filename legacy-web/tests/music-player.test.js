const assert = require('assert');
const { parseYouTubeId, formatDuration } = require('../public/js/music-player');

assert.strictEqual(parseYouTubeId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), 'dQw4w9WgXcQ', 'Standard youtube url parsed');
assert.strictEqual(parseYouTubeId('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ', 'Short youtu.be url parsed');
assert.strictEqual(parseYouTubeId('https://www.youtube.com/embed/dQw4w9WgXcQ'), 'dQw4w9WgXcQ', 'Embed url parsed');
assert.strictEqual(parseYouTubeId('not a url'), null, 'Invalid url returns null');

assert.strictEqual(formatDuration(0), '00:00');
assert.strictEqual(formatDuration(66), '01:06');
assert.strictEqual(formatDuration(125), '02:05');
assert.strictEqual(formatDuration(3665), '01:01:05');

console.log('music-player tests passed');
