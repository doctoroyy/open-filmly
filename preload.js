"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const electron_1 = require("electron");
const ipc_client_1 = require("./ipc-client");
const ipc_channels_1 = require("./ipc-channels");
// 创建类型安全的IPC客户端
const ipcClient = (0, ipc_client_1.createIPCClient)(electron_1.ipcRenderer);
const electronAPI = new ipc_client_1.ElectronAPI(ipcClient, ipc_channels_1.IPCChannels);
// 暴露安全的API给渲染进程
electron_1.contextBridge.exposeInMainWorld("electronAPI", {
    // 配置相关
    getConfig: () => electronAPI.config.getConfig(),
    saveConfig: (config) => electronAPI.config.saveConfig(config),
    connectServer: (serverConfig) => electronAPI.server.connectServer(serverConfig),
    goDiscoverShares: (serverConfig) => electronAPI.server.goDiscoverShares(serverConfig),
    listShares: () => electronAPI.server.listShares(),
    listFolders: (shareName) => electronAPI.server.listFolders(shareName),
    // 获取目录内容（包括文件和文件夹），用于浏览目录
    getDirContents: (dirPath) => electronAPI.server.getDirContents(dirPath),
    // 媒体相关
    getMedia: (type) => electronAPI.media.getMedia(type),
    // 根据ID获取媒体
    getMediaById: (id) => electronAPI.media.getMediaById(id),
    // 获取最近观看的媒体
    getRecentlyViewed: () => electronAPI.media.getRecentlyViewed(),
    scanMedia: (type, useCached = true) => electronAPI.media.scanMedia(type, useCached),
    playMedia: (request) => electronAPI.media.playMedia(request),
    // 添加单个媒体文件
    addSingleMedia: (filePath) => electronAPI.media.addSingleMedia(filePath),
    // 海报相关
    fetchPosters: (mediaIds) => electronAPI.metadata.fetchPosters(mediaIds),
    // 文件选择
    selectFolder: () => electronAPI.filesystem.selectFolder(),
    // 缓存控制
    clearMediaCache: () => electronAPI.media.clearMediaCache(),
    // TMDB API相关函数
    checkTmdbApi: () => electronAPI.config.checkTmdbApi(),
    getTmdbApiKey: () => electronAPI.config.getTmdbApiKey(),
    setTmdbApiKey: (apiKey) => electronAPI.config.setTmdbApiKey(apiKey),
    // 从本地读取媒体详情
    getMediaDetails: (mediaId) => electronAPI.media.getMediaDetails(mediaId),
    // MPV 相关
    checkMpvAvailability: () => electronAPI.media.checkMpvAvailability(),
    // 暴露原始客户端供高级用法
    _client: ipcClient,
    // 暴露类型化API对象供高级用法
    _api: electronAPI,
});
//# sourceMappingURL=preload.js.map