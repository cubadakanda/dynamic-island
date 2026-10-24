const { app, BrowserWindow, screen } = require('electron');
const path = require('path');
const { createAppState } = require('./app');

let mainWindow = null;
let appState = null;

async function createWindow() {
  appState = createAppState();
  const { url } = await appState.init();

  const primaryDisplay = screen.getPrimaryDisplay();
  const { width: screenWidth } = primaryDisplay.workAreaSize;

  const winWidth = 600;
  const winHeight = 220;
  const x = Math.round((screenWidth - winWidth) / 2);
  const y = 0;

  mainWindow = new BrowserWindow({
    width: winWidth,
    height: winHeight,
    x: x,
    y: y,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    hasShadow: false,
    resizable: false,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    }
  });

  mainWindow.setAlwaysOnTop(true, 'screen-saver');
  mainWindow.loadURL(url);

  mainWindow.on('closed', () => {
    mainWindow = null;
    if (appState) appState.shutdown();
  });
}

// Support unit/smoke tests without requiring Electron display server
if (process.argv.includes('--smoke-test')) {
  appState = createAppState();
  appState.init().then(({ url }) => {
    console.log(`Smoke test passed. Server started at ${url}`);
    appState.shutdown();
    process.exit(0);
  });
} else {
  app.whenReady().then(createWindow);

  app.on('window-all-closed', () => {
    if (appState) appState.shutdown();
    app.quit();
  });
}

module.exports = { createWindow };
