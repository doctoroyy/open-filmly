export interface ElectronAPI {
  // 配置相关
  getConfig: () => Promise<SambaConfig | null>;
  saveConfig: (config: SambaConfig) => Promise<{ success: boolean; error?: string }>;
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

  // 新增：获取目录内容
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

  // 媒体相关
  getMedia: (type: "movie" | "tv" | "unknown" | "all") => Promise<Media[]>;
  getMediaById: (id: string) => Promise<Media | null>;
  getRecentlyViewed: () => Promise<Media[]>;
  
  // 新增：全文搜索媒体
  searchMedia: (searchTerm: string) => Promise<{
    success: boolean;
    results: Media[];
    count: number;
    error?: string;
  }>;
  
  scanMedia: (type?: "movie" | "tv" | "all", useCached?: boolean) => Promise<{ 
    success: boolean; 
    count?: number;
    movieCount?: number;
    tvCount?: number;
    error?: string;
  }>;
  playMedia: (mediaId: string, filePath?: string) => Promise<{ success: boolean; error?: string }>;
  
  // 新增：直接添加媒体文件
  addSingleMedia: (filePath: string) => Promise<{ 
    success: boolean; 
    media?: Media; 
    error?: string 
  }>;

  // 海报相关
  fetchPosters: (mediaIds: string[]) => Promise<{ success: boolean; results: any; error?: string }>;

  // 文件选择
  selectFolder: () => Promise<{ canceled: boolean; filePaths?: string[] }>;
  
  // 缓存控制
  clearMediaCache: () => Promise<{
    success: boolean;
    error?: string;
  }>;

  // TMDB API相关方法
  checkTmdbApi: () => Promise<{
    success: boolean;
    hasApiKey: boolean;
    error?: string;
  }>;
  getTmdbApiKey: () => Promise<{
    success: boolean;
    apiKey?: string | null;
    error?: string;
  }>;
  setTmdbApiKey: (apiKey: string) => Promise<{
    success: boolean;
    error?: string;
  }>;

  getMediaDetails: (mediaId: string) => Promise<MediaItem | null>;
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