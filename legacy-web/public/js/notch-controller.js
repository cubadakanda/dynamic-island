function formatClock(date = new Date()) {
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  return `${hours}:${minutes}`;
}

const VALID_TABS = ['shelf', 'music', 'pomodoro'];

function isValidTab(tab) {
  return VALID_TABS.includes(tab);
}

class NotchController {
  constructor() {
    this.isExpanded = false;
    this.activeTab = 'music';
    this.leaveTimeout = null;
    this.initDOM();
  }

  initDOM() {
    if (typeof document === 'undefined') return;

    this.notchEl = document.getElementById('notch');
    this.clockEl = document.getElementById('clock-text');
    this.dateEl = document.getElementById('date-text');
    this.tabButtons = document.querySelectorAll('.tab-btn');
    this.tabContents = document.querySelectorAll('.tab-pane');

    if (this.notchEl) {
      this.notchEl.addEventListener('mouseenter', () => this.handleMouseEnter());
      this.notchEl.addEventListener('mouseleave', () => this.handleMouseLeave());
    }

    if (this.tabButtons) {
      this.tabButtons.forEach(btn => {
        btn.addEventListener('click', (e) => {
          const tab = e.currentTarget.getAttribute('data-tab');
          this.switchTab(tab);
        });
      });
    }

    this.startClock();
  }

  handleMouseEnter() {
    if (this.leaveTimeout) {
      clearTimeout(this.leaveTimeout);
      this.leaveTimeout = null;
    }
    this.setExpanded(true);
  }

  handleMouseLeave() {
    this.leaveTimeout = setTimeout(() => {
      this.setExpanded(false);
    }, 280);
  }

  setExpanded(expanded) {
    this.isExpanded = expanded;
    if (!this.notchEl) return;
    if (expanded) {
      this.notchEl.classList.add('expanded');
    } else {
      this.notchEl.classList.remove('expanded');
    }
  }

  switchTab(tabName) {
    if (!isValidTab(tabName)) return;
    this.activeTab = tabName;

    if (!this.tabButtons) return;

    this.tabButtons.forEach(btn => {
      if (btn.getAttribute('data-tab') === tabName) {
        btn.classList.add('active');
      } else {
        btn.classList.remove('active');
      }
    });

    this.tabContents.forEach(pane => {
      if (pane.id === `tab-${tabName}`) {
        pane.classList.add('active');
      } else {
        pane.classList.remove('active');
      }
    });
  }

  startClock() {
    const update = () => {
      const now = new Date();
      if (this.clockEl) this.clockEl.textContent = formatClock(now);
      if (this.dateEl) {
        const options = { weekday: 'short', day: 'numeric', month: 'short' };
        this.dateEl.textContent = `${now.toLocaleDateString('en-US', options)} • ${formatClock(now)}`;
      }
    };
    update();
    setInterval(update, 1000);
  }
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    formatClock,
    isValidTab,
    NotchController
  };
}
