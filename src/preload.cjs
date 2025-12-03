const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  getCountdowns: () => ipcRenderer.invoke('get-countdowns'),
  saveCountdown: (countdown) => ipcRenderer.invoke('save-countdown', countdown),
  deleteCountdown: (id) => ipcRenderer.invoke('delete-countdown', id),
  pinCountdown: (id) => ipcRenderer.invoke('pin-countdown', id),
  getAIConfig: () => ipcRenderer.invoke('get-ai-config'),
  saveAIConfig: (config) => ipcRenderer.invoke('save-ai-config', config),
});
