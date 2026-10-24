const assert = require('assert');
const { ShelfEngine } = require('../src/shelf-engine');

const shelf = new ShelfEngine();
const items = shelf.addFiles(['C:\\test\\document.pdf', 'C:\\test\\image.png']);
assert.strictEqual(items.length, 2, 'Should add 2 files');
assert.strictEqual(items[0].name, 'document.pdf', 'First file name should match');
assert.strictEqual(items[1].name, 'image.png', 'Second file name should match');

// Duplicate check
const addedAgain = shelf.addFiles(['C:\\test\\document.pdf']);
assert.strictEqual(shelf.getItems().length, 2, 'Duplicates should not be added');

shelf.removeFile(items[0].id);
assert.strictEqual(shelf.getItems().length, 1, 'Should have 1 item left');
assert.strictEqual(shelf.getItems()[0].name, 'image.png');

shelf.clear();
assert.strictEqual(shelf.getItems().length, 0, 'Clear should empty the shelf');

console.log('shelf-engine tests passed');
