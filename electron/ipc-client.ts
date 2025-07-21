/**
 * 类型安全的IPC客户端
 * 用于渲染进程中调用主进程的IPC方法
 */

import { IPCChannels, IPCChannelName, AllIPCTypes } from './ipc-channels'

// 客户端接口定义
export interface IPCClient {
  invoke<T extends IPCChannelName>(
    channel: T,
    ...args: T extends keyof AllIPCTypes 
      ? AllIPCTypes[T]['request'] extends void 
        ? [] 
        : [AllIPCTypes[T]['request']]
      : any[]
  ): Promise<T extends keyof AllIPCTypes ? AllIPCTypes[T]['response'] : any>
}

/**
 * 创建类型安全的IPC客户端
 * @param ipcRenderer electron的ipcRenderer实例
 */
export function createIPCClient(ipcRenderer: any): IPCClient {
  const client: IPCClient = {
    async invoke<T extends IPCChannelName>(
      channel: T,
      ...args: any[]
    ): Promise<any> {
      try {
        return await ipcRenderer.invoke(channel, ...args)
      } catch (error) {
        console.error(`[IPC Client] Error invoking ${channel}:`, error)
        throw error
      }
    }
  }

  return client
}

/**
 * 便利方法：配置相关的API
 */
export class ConfigAPI {
  constructor(private client: IPCClient) {}

  async getConfig() {
    return this.client.invoke(IPCChannels.GET_CONFIG)
  }

  async saveConfig(config: any) {
    return this.client.invoke(IPCChannels.SAVE_CONFIG, config)
  }

  async getTmdbApiKey() {
    return this.client.invoke(IPCChannels.GET_TMDB_API_KEY)
  }

  async setTmdbApiKey(apiKey: string) {
    return this.client.invoke(IPCChannels.SET_TMDB_API_KEY, apiKey)
  }

  async checkTmdbApi() {
    return this.client.invoke(IPCChannels.CHECK_TMDB_API)
  }
}

/**
 * 便利方法：服务器相关的API
 */
export class ServerAPI {
  constructor(private client: IPCClient) {}

  async connectServer(serverConfig: any) {
    return this.client.invoke(IPCChannels.CONNECT_SERVER, serverConfig)
  }

  async goDiscoverShares(serverConfig: any) {
    return this.client.invoke(IPCChannels.GO_DISCOVER, serverConfig)
  }

  async listShares() {
    return this.client.invoke(IPCChannels.LIST_SHARES)
  }

  async listFolders(shareName: string) {
    return this.client.invoke(IPCChannels.LIST_FOLDERS, shareName)
  }

  async getDirContents(dirPath: string) {
    return this.client.invoke(IPCChannels.GET_DIR_CONTENTS, dirPath)
  }
}

/**
 * 便利方法：媒体相关的API
 */
export class MediaAPI {
  constructor(private client: IPCClient) {}

  async getMedia(type: string) {
    return this.client.invoke(IPCChannels.GET_MEDIA, type)
  }

  async getMediaById(id: string) {
    return this.client.invoke(IPCChannels.GET_MEDIA_BY_ID, id)
  }

  async getMediaDetails(mediaId: string) {
    return this.client.invoke(IPCChannels.GET_MEDIA_DETAILS, mediaId)
  }

  async getRecentlyViewed() {
    return this.client.invoke(IPCChannels.GET_RECENTLY_VIEWED)
  }

  async scanMedia(type: "movie" | "tv" | "all", useCached: boolean = true) {
    return this.client.invoke(IPCChannels.SCAN_MEDIA, { type, useCached })
  }

  async addSingleMedia(filePath: string) {
    return this.client.invoke(IPCChannels.ADD_SINGLE_MEDIA, filePath)
  }

  async playMedia(request: string | { mediaId: string; filePath?: string }) {
    return this.client.invoke(IPCChannels.PLAY_MEDIA, request)
  }

  async searchMedia(searchTerm: string) {
    return this.client.invoke(IPCChannels.SEARCH_MEDIA, searchTerm)
  }

  async searchMediaByPath(searchTerm: string) {
    return this.client.invoke(IPCChannels.SEARCH_MEDIA_BY_PATH, searchTerm)
  }

  async clearMediaCache() {
    return this.client.invoke(IPCChannels.CLEAR_MEDIA_CACHE)
  }

  async checkMpvAvailability() {
    return this.client.invoke(IPCChannels.CHECK_MPV_AVAILABILITY)
  }
}

/**
 * 便利方法：元数据相关的API
 */
export class MetadataAPI {
  constructor(private client: IPCClient) {}

  async fetchPosters(mediaIds: string[]) {
    return this.client.invoke(IPCChannels.FETCH_POSTERS, mediaIds)
  }
}

/**
 * 便利方法：文件系统相关的API
 */
export class FileSystemAPI {
  constructor(private client: IPCClient) {}

  async selectFolder() {
    return this.client.invoke(IPCChannels.SELECT_FOLDER)
  }
}

/**
 * 组合所有API的统一接口
 */
export class ElectronAPI {
  public config: ConfigAPI
  public server: ServerAPI
  public media: MediaAPI
  public metadata: MetadataAPI
  public filesystem: FileSystemAPI

  constructor(client: IPCClient) {
    this.config = new ConfigAPI(client)
    this.server = new ServerAPI(client)
    this.media = new MediaAPI(client)
    this.metadata = new MetadataAPI(client)
    this.filesystem = new FileSystemAPI(client)
  }
}