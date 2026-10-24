function parseYouTubeId(input) {
  if (!input || typeof input !== 'string') return null;
  const match = input.match(/(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})/);
  return match ? match[1] : null;
}

function formatDuration(seconds = 0) {
  const s = Math.floor(seconds % 60);
  const m = Math.floor((seconds / 60) % 60);
  const h = Math.floor(seconds / 3600);

  const pad = (n) => String(n).padStart(2, '0');

  if (h > 0) {
    return `${pad(h)}:${pad(m)}:${pad(s)}`;
  }
  return `${pad(m)}:${pad(s)}`;
}

class MusicPlayerUI {
  constructor() {
    this.isPlaying = false;
    this.currentTrack = {
      title: 'No Music Playing',
      artist: 'YouTube Audio / Windows Media',
      albumArt: null,
      duration: 0,
      currentTime: 0
    };
    this.ytPlayer = null;
    this.initDOM();
  }

  initDOM() {
    if (typeof document === 'undefined') return;

    this.titleEl = document.getElementById('track-title');
    this.artistEl = document.getElementById('track-artist');
    this.btnPlay = document.getElementById('btn-play');
    this.btnPrev = document.getElementById('btn-prev');
    this.btnNext = document.getElementById('btn-next');
    this.searchInput = document.getElementById('yt-search-input');
    this.lyricsEl = document.getElementById('lyric-text');

    if (this.btnPlay) {
      this.btnPlay.addEventListener('click', () => this.togglePlay());
    }

    if (this.searchInput) {
      this.searchInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          const val = this.searchInput.value.trim();
          this.handleSearchOrUrl(val);
        }
      });
    }
  }

  handleSearchOrUrl(input) {
    const videoId = parseYouTubeId(input);
    if (videoId) {
      this.loadYouTubeVideo(videoId, 'YouTube Stream');
    } else if (input) {
      // Direct track title simulation or search
      this.setTrack({
        title: input,
        artist: 'YouTube Audio',
        lyrics: `Memutar audio YouTube untuk: "${input}"`
      });
      this.play();
    }
  }

  loadYouTubeVideo(videoId, title = 'YouTube Audio') {
    this.setTrack({
      title,
      artist: 'YouTube Player',
      lyrics: 'Audio streaming dari YouTube...'
    });
    this.play();
  }

  setTrack(track) {
    this.currentTrack = { ...this.currentTrack, ...track };
    if (this.titleEl) this.titleEl.textContent = this.currentTrack.title;
    if (this.artistEl) this.artistEl.textContent = this.currentTrack.artist;
    if (this.lyricsEl && this.currentTrack.lyrics) {
      this.lyricsEl.textContent = this.currentTrack.lyrics;
    }
  }

  togglePlay() {
    if (this.isPlaying) {
      this.pause();
    } else {
      this.play();
    }
  }

  play() {
    this.isPlaying = true;
    if (this.btnPlay) this.btnPlay.textContent = '⏸';
  }

  pause() {
    this.isPlaying = false;
    if (this.btnPlay) this.btnPlay.textContent = '▶';
  }
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    parseYouTubeId,
    formatDuration,
    MusicPlayerUI
  };
}
