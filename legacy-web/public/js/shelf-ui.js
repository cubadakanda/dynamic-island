class ShelfUI {
  constructor(options = {}) {
    this.dropZone = document.getElementById('shelf-drop-zone');
    this.itemsContainer = document.getElementById('shelf-items-list');
    this.badgeEl = document.getElementById('shelf-count-badge');
    this.items = [];
    this.initEvents();
  }

  initEvents() {
    if (!this.dropZone) return;

    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      this.dropZone.addEventListener(eventName, (e) => {
        e.preventDefault();
        e.stopPropagation();
      }, false);
    });

    this.dropZone.addEventListener('dragover', () => {
      this.dropZone.style.borderColor = '#3b82f6';
      this.dropZone.style.backgroundColor = 'rgba(59, 130, 246, 0.08)';
    });

    this.dropZone.addEventListener('dragleave', () => {
      this.dropZone.style.borderColor = 'var(--shelf-border)';
      this.dropZone.style.backgroundColor = 'transparent';
    });

    this.dropZone.addEventListener('drop', (e) => {
      this.dropZone.style.borderColor = 'var(--shelf-border)';
      this.dropZone.style.backgroundColor = 'transparent';

      const files = Array.from(e.dataTransfer.files || []);
      if (files.length > 0) {
        files.forEach(file => {
          this.addItem({
            id: `${Date.now()}-${Math.random().toString(36).substring(2, 6)}`,
            name: file.name,
            size: file.size,
            path: file.path || file.name
          });
        });
      }
    });
  }

  addItem(file) {
    if (this.items.some(i => i.name === file.name)) return;
    this.items.push(file);
    this.render();
  }

  removeItem(id) {
    this.items = this.items.filter(i => i.id !== id);
    this.render();
  }

  clear() {
    this.items = [];
    this.render();
  }

  formatSize(bytes) {
    if (!bytes) return '';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  render() {
    if (this.badgeEl) {
      this.badgeEl.textContent = this.items.length > 0 ? `(${this.items.length})` : '';
    }

    if (!this.itemsContainer) return;
    this.itemsContainer.innerHTML = '';

    if (this.items.length === 0) {
      return;
    }

    this.items.forEach(item => {
      const card = document.createElement('div');
      card.style.cssText = 'background: #1a1e2a; border: 1px solid #2e3547; border-radius: 8px; padding: 6px 10px; display: flex; align-items: center; gap: 8px; font-size: 11px; color: #fff; cursor: grab; flex-shrink: 0;';
      card.draggable = true;

      card.innerHTML = `
        <span style="font-size: 14px;">📄</span>
        <div style="max-width: 110px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
          <div style="font-weight: 600;">${item.name}</div>
          <div style="font-size: 9px; color: #94a3b8;">${this.formatSize(item.size)}</div>
        </div>
        <button style="background: none; border: none; color: #ef4444; cursor: pointer; font-size: 12px; margin-left: 4px;">&times;</button>
      `;

      card.querySelector('button').addEventListener('click', (e) => {
        e.stopPropagation();
        this.removeItem(item.id);
      });

      this.itemsContainer.appendChild(card);
    });
  }
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { ShelfUI };
}
