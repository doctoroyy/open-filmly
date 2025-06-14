/**
 * Electron API接口定义 - 类型安全的IPC通信
 * 
 * 这个接口使用了新的类型安全IPC架构，提供了：
 * - ✅ 集中化的通道定义，避免字符串硬编码
 * - ✅ 完整的类型安全支持
 * - ✅ 统一的错误处理
 * - ✅ 调试友好的日志输出
 * - ✅ 更好的代码可维护性
 */
export interface ElectronAPI {
  // 配置相关 - 使用ConfigChannels
  getConfig: () => Promise<SambaConfig | null>;
  saveConfig: (config: SambaConfig) => Promise<{ success: boolean; error?: string }>;
  checkTmdbApi: () => Promise<{ success: boolean; hasApiKey: boolean; error?: string }>;
  getTmdbApiKey: () => Promise<{ success: boolean; apiKey?: string | null; error?: string }>;
  setTmdbApiKey: (apiKey: string) => Promise<{ success: boolean; error?: string }>;

  // 服务器连接相关 - 使用ServerChannels
  connectServer: (serverConfig: SambaConfig) => Promise<{
    success: boolean;
    files?: string[];
    shares?: string[];
    needShareSelection?: boolean;
    error?: string;
    errorType?: string;
  }>;
  listShares: () => Promise<{ success: boolean; shares: string[]; error?: string }>;
  listFolders: (shareName: string) => Promise<{ success: boolean; folders: string[]; error?: string }>;
  getDirContents: (dirPath: string) => Promise<{ 
    success: boolean; 
    items?: Array<{
      name: string;
      isDirectory: boolean;
      size?: number;
      modifiedTime?: string;
    }>;
    error?: string 
  }>;

  // 媒体相关 - 使用MediaChannels
  getMedia: (type: "movie" | "tv" | "unknown" | "all") => Promise<Media[]>;
  getMediaById: (id: string) => Promise<Media | null>;
  getMediaDetails: (mediaId: string) => Promise<MediaItem | null>;
  getRecentlyViewed: () => Promise<Media[]>;
  scanMedia: (type?: "movie" | "tv" | "all", useCached?: boolean) => Promise<{ 
    success: boolean; 
    count?: number;
    movieCount?: number;
    tvCount?: number;
    error?: string;
  }>;
  addSingleMedia: (filePath: string) => Promise<{ 
    success: boolean; 
    media?: Media; 
    error?: string 
  }>;
  playMedia: (mediaId: string, filePath?: string) => Promise<{ success: boolean; error?: string }>;
  searchMedia: (searchTerm: string) => Promise<{
    success: boolean;
    results: Media[];
    count: number;
    error?: string;
  }>;
  clearMediaCache: () => Promise<{ success: boolean; error?: string }>;

  // 元数据相关 - 使用MetadataChannels
  fetchPosters: (mediaIds: string[]) => Promise<{ success: boolean; results: any; error?: string }>;

  // 文件系统相关 - 使用FileSystemChannels
  selectFolder: () => Promise<{ canceled: boolean; filePaths?: string[] }>;

  // 高级API访问（用于调试和扩展）
  _client?: any; // IPCClient类型，用于直接IPC调用
  _api?: any;    // ElectronAPI类型，用于组织化的API访问
}

export interface SambaConfig {
  ip: string;
  port?: number;
  username?: string;
  password?: string;
  domain?: string;
  sharePath?: string;
  selectedFolders?: string[];
}

export interface Media {
  id: string;
  title: string;
  year: string;
  type: "movie" | "tv" | "unknown";
  path: string;
  fullPath?: string;
  posterPath?: string | null;
  rating?: string;
  details?: string;
  dateAdded: string;
  lastUpdated: string;
  episodeCount?: number;
  episodes?: {
    path: string;
    name: string;
    season: number;
    episode: number;
  }[];
}

declare global {
  interface Window {
    electronAPI: ElectronAPI;
  }
} 