const path = require('path');

class ShelfEngine {
  constructor() {
    this.items = [];
  }

  addFiles(filePaths = []) {
    const added = [];
    for (const filePath of filePaths) {
      if (!filePath) continue;
      const normalized = path.normalize(filePath);
      const exists = this.items.some(item => item.path === normalized);
      if (exists) continue;

      const fileName = path.basename(normalized);
      const ext = path.extname(normalized).toLowerCase();
      const id = `${Date.now()}-${Math.random().toString(36).substring(2, 9)}`;

      const item = {
        id,
        name: fileName,
        path: normalized,
        extension: ext,
        addedAt: new Date().toISOString()
      };

      this.items.push(item);
      added.push(item);
    }
    return this.items;
  }

  removeFile(id) {
    this.items = this.items.filter(item => item.id !== id);
    return this.items;
  }

  clear() {
    this.items = [];
    return this.items;
  }

  getItems() {
    return [...this.items];
  }
}

module.exports = { ShelfEngine };
