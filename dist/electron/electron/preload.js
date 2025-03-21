"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const electron_1 = require("electron");
// 暴露安全的API给渲染进程
electron_1.contextBridge.exposeInMainWorld("electronAPI", {
    // 配置相关
    getConfig: () => electron_1.ipcRenderer.invoke("get-config"),
    saveConfig: (config) => electron_1.ipcRenderer.invoke("save-config", config),
    // 媒体相关
    getMedia: (type) => electron_1.ipcRenderer.invoke("get-media", type),
    scanMedia: (type) => electron_1.ipcRenderer.invoke("scan-media", type),
    playMedia: (mediaId) => electron_1.ipcRenderer.invoke("play-media", mediaId),
    // 海报相关
    fetchPosters: (mediaIds) => electron_1.ipcRenderer.invoke("fetch-posters", mediaIds),
    // 文件选择
    selectFolder: () => electron_1.ipcRenderer.invoke("select-folder"),
});
//# sourceMappingURL=preload.js.map