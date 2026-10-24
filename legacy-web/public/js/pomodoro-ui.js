class PomodoroUI {
  constructor() {
    this.focusDuration = 25 * 60;
    this.breakDuration = 5 * 60;
    this.remainingSeconds = this.focusDuration;
    this.mode = 'focus';
    this.isRunning = false;
    this.timerInterval = null;

    this.timerEl = document.getElementById('pomodoro-timer');
    this.labelEl = document.getElementById('pomodoro-mode-label');
    this.btnStart = document.getElementById('btn-pomo-start');
    this.btnReset = document.getElementById('btn-pomo-reset');
    this.btnToggleMode = document.getElementById('btn-pomo-toggle-mode');

    this.initDOM();
  }

  initDOM() {
    if (!this.btnStart) return;

    this.btnStart.addEventListener('click', () => this.toggleStart());
    if (this.btnReset) {
      this.btnReset.addEventListener('click', () => this.reset());
    }
    if (this.btnToggleMode) {
      this.btnToggleMode.addEventListener('click', () => this.toggleMode());
    }
    this.updateDisplay();
  }

  toggleStart() {
    if (this.isRunning) {
      this.pause();
    } else {
      this.start();
    }
  }

  start() {
    this.isRunning = true;
    if (this.btnStart) {
      this.btnStart.textContent = 'Jeda';
      this.btnStart.style.background = '#eab308';
    }
    this.timerInterval = setInterval(() => {
      if (this.remainingSeconds > 0) {
        this.remainingSeconds--;
        this.updateDisplay();
      } else {
        this.pause();
        this.onComplete();
      }
    }, 1000);
  }

  pause() {
    this.isRunning = false;
    if (this.btnStart) {
      this.btnStart.textContent = 'Mulai';
      this.btnStart.style.background = '#10b981';
    }
    if (this.timerInterval) {
      clearInterval(this.timerInterval);
      this.timerInterval = null;
    }
  }

  reset() {
    this.pause();
    this.remainingSeconds = (this.mode === 'focus') ? this.focusDuration : this.breakDuration;
    this.updateDisplay();
  }

  toggleMode() {
    this.pause();
    this.mode = (this.mode === 'focus') ? 'break' : 'focus';
    this.remainingSeconds = (this.mode === 'focus') ? this.focusDuration : this.breakDuration;
    if (this.btnToggleMode) {
      this.btnToggleMode.textContent = (this.mode === 'focus') ? 'Mode Istirahat' : 'Mode Fokus';
    }
    this.updateDisplay();
  }

  onComplete() {
    alert(this.mode === 'focus' ? '🎉 Waktu fokus selesai! Saatnya istirahat sejenak.' : '⏰ Waktu istirahat selesai! Mari fokus kembali.');
  }

  formatTime(seconds) {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }

  updateDisplay() {
    if (this.timerEl) {
      this.timerEl.textContent = this.formatTime(this.remainingSeconds);
    }
    if (this.labelEl) {
      this.labelEl.textContent = (this.mode === 'focus') ? 'FOKUS AKTIF' : 'WAKTU ISTIRAHAT';
      this.labelEl.style.color = (this.mode === 'focus') ? '#10b981' : '#38bdf8';
    }
  }
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { PomodoroUI };
}
