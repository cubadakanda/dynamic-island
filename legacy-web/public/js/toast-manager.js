class ToastQueue {
  constructor() {
    this.queue = [];
  }

  push(toast) {
    this.queue.push(toast);
  }

  getCurrent() {
    return this.queue.length > 0 ? this.queue[0] : null;
  }

  dismiss() {
    return this.queue.shift();
  }

  isEmpty() {
    return this.queue.length === 0;
  }
}

class ToastManager {
  constructor(options = {}) {
    this.queue = new ToastQueue();
    this.isShowing = false;
    this.durationMs = options.durationMs || 3500;
    this.toastEl = null;
    this.initDOM();
  }

  initDOM() {
    if (typeof document === 'undefined') return;

    this.toastEl = document.createElement('div');
    this.toastEl.id = 'dynamic-toast';
    this.toastEl.style.cssText = `
      position: absolute;
      top: 0;
      left: 50%;
      transform: translateX(-50%) translateY(-100%);
      background: #000;
      border: 1px solid rgba(255, 255, 255, 0.2);
      border-top: none;
      border-bottom-left-radius: 18px;
      border-bottom-right-radius: 18px;
      color: #fff;
      padding: 6px 18px;
      font-size: 11px;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 10px;
      z-index: 1000;
      transition: transform 0.35s cubic-bezier(0.16, 1, 0.3, 1);
      box-shadow: 0 8px 24px rgba(0,0,0,0.8);
      white-space: nowrap;
    `;
    document.body.appendChild(this.toastEl);
  }

  showToast(data) {
    this.queue.push(data);
    if (!this.isShowing) {
      this.processNext();
    }
  }

  processNext() {
    const current = this.queue.getCurrent();
    if (!current) {
      this.isShowing = false;
      return;
    }

    this.isShowing = true;
    if (this.toastEl) {
      const icon = current.type === 'bluetooth' ? '🎧' : (current.type === 'battery' ? '⚡' : '🔔');
      this.toastEl.innerHTML = `<span>${icon}</span> <span>${current.title}</span> <span style="color:#94a3b8;font-size:10px;">${current.subtitle || ''}</span>`;
      this.toastEl.style.transform = 'translateX(-50%) translateY(0)';
    }

    setTimeout(() => {
      if (this.toastEl) {
        this.toastEl.style.transform = 'translateX(-50%) translateY(-100%)';
      }
      setTimeout(() => {
        this.queue.dismiss();
        this.processNext();
      }, 350);
    }, this.durationMs);
  }
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { ToastQueue, ToastManager };
}
