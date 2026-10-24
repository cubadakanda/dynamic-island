class PomodoroEngine {
  constructor(options = {}) {
    this.focusDuration = options.focusDuration || 25 * 60;
    this.breakDuration = options.breakDuration || 5 * 60;
    this.mode = 'focus'; // 'focus' | 'break'
    this.isRunning = false;
    this.remainingSeconds = this.focusDuration;
  }

  setMode(mode) {
    if (mode !== 'focus' && mode !== 'break') return;
    this.mode = mode;
    this.remainingSeconds = (mode === 'focus') ? this.focusDuration : this.breakDuration;
    this.isRunning = false;
  }

  start() {
    this.isRunning = true;
  }

  pause() {
    this.isRunning = false;
  }

  reset() {
    this.isRunning = false;
    this.remainingSeconds = (this.mode === 'focus') ? this.focusDuration : this.breakDuration;
  }

  tick() {
    if (this.remainingSeconds > 0) {
      this.remainingSeconds -= 1;
      return true;
    }
    this.isRunning = false;
    return false; // completed
  }

  formatTime(seconds = this.remainingSeconds) {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
  }

  getState() {
    return {
      mode: this.mode,
      isRunning: this.isRunning,
      remainingSeconds: this.remainingSeconds,
      formattedTime: this.formatTime()
    };
  }
}

module.exports = { PomodoroEngine };
