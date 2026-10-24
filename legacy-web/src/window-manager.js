const http = require('http');
const fs = require('fs');
const path = require('path');
const cp = require('child_process');

function calculateWindowBounds(screen, isExpanded) {
  const width = isExpanded ? 560 : 140;
  const height = isExpanded ? 190 : 32;
  const x = Math.round((screen.width - width) / 2);
  const y = 0;
  return { x, y, width, height };
}

class WindowManager {
  constructor(options = {}) {
    this.port = options.port || 49820;
    this.server = null;
    this.isExpanded = false;
    this.screen = options.screen || { width: 1920, height: 1080, scaleFactor: 1.0 };
  }

  startServer(publicDir) {
    const mimeTypes = {
      '.html': 'text/html',
      '.css': 'text/css',
      '.js': 'application/javascript',
      '.json': 'application/json',
      '.png': 'image/png',
      '.svg': 'image/svg+xml'
    };

    this.server = http.createServer((req, res) => {
      let reqPath = req.url.split('?')[0];
      if (reqPath === '/') reqPath = '/index.html';
      const filePath = path.join(publicDir, reqPath);

      fs.readFile(filePath, (err, data) => {
        if (err) {
          res.writeHead(404, { 'Content-Type': 'text/plain' });
          res.end('Not Found');
          return;
        }
        const ext = path.extname(filePath);
        res.writeHead(200, { 'Content-Type': mimeTypes[ext] || 'application/octet-stream' });
        res.end(data);
      });
    });

    return new Promise((resolve) => {
      this.server.listen(this.port, '127.0.0.1', () => {
        resolve(`http://127.0.0.1:${this.port}`);
      });
    });
  }

  stopServer() {
    if (this.server) {
      this.server.close();
      this.server = null;
    }
  }

  getBounds() {
    return calculateWindowBounds(this.screen, this.isExpanded);
  }

  setExpanded(expanded) {
    this.isExpanded = expanded;
    return this.getBounds();
  }
}

module.exports = {
  calculateWindowBounds,
  WindowManager
};
