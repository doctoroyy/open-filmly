import SMB2 from '@tryjsky/v9u-smb2';
import * as path from "path";
import * as fs from "fs";
import * as os from "os";
import * as net from "net";
import { exec } from 'child_process';
import { promisify } from 'util';

const execPromise = promisify(exec);

interface SambaConfig {
  ip: string
  port?: number
  username?: string
  password?: string
  domain?: string
  sharePath?: string
}

interface MediaFile {
  path: string
  type: 'movie' | 'tv' | 'unknown'
  name: string
  fullPath: string
}

// 常见的SMB共享名称列表
const COMMON_SHARE_NAMES = [
  'wd', 'media', 'share', 'public', 'videos', 'movies', 'tv', 'photos', 
  'music', 'downloads', 'documents', 'home', 'wd-downloads', 'mi-camera', 'nobody'
];

export class SambaClient {
  private config: SambaConfig | null = null;
  private client: any = null;
  private discoveredShares: string[] = [];

  constructor() {
    // 默认配置，只提供常用端口，让用户配置其他选项
    this.config = {
      ip: "", // 用户需要设置服务器IP
      port: 445, // SMB标准端口
      username: "", // 用户需要设置
      password: "", // 用户需要设置
      sharePath: "", // 用户需要设置共享名
    };
  }

  // 配置Samba客户端
  public configure(config: SambaConfig): void {
    this.config = {
      ...this.config,
      ...config,
    };

    // 重置客户端，下次使用时会重新创建
    this.disconnect();
  }

  // 测试连接是否有效
  public async testConnection(): Promise<boolean> {
    try {
      if (!this.config || !this.config.ip) {
        throw new Error("Configuration incomplete: IP address is required");
      }
      
      console.log("Testing connection to SMB server...");
      
      // 尝试直接获取服务器上的所有共享
      const shares = await this.listServerShares();
      
      if (shares && shares.length > 0) {
        console.log(`Found shares on server: ${shares.join(', ')}`);
        this.discoveredShares = shares;
        return true;
      } else {
        // 如果没有找到共享，尝试自动发现
        console.log("No shares found using direct method, trying auto discovery...");
        const discoveredShares = await this.autoDiscoverShares();
        if (discoveredShares && discoveredShares.length > 0) {
          console.log(`Found shares via discovery: ${discoveredShares.join(', ')}`);
          this.discoveredShares = discoveredShares;
          return true;
        }
      }
      
      throw new Error("No shares found on the server");
    } catch (error: any) {
      console.error('Connection test failed:', error.message || error);
      throw error;
    }
  }

  // 列出服务器上的所有共享（直接使用smbclient，如果可用）
  public async listServerShares(): Promise<string[]> {
    if (!this.config || !this.config.ip) {
      throw new Error("Server IP must be specified to list shares");
    }

    console.log(`直接获取服务器 ${this.config.ip} 上的所有共享...`);
    
    try {
      // 首先检查服务器是否可达
      await this.pingServer(this.config.ip, this.config.port || 445);
      
      // 首先尝试使用系统自带的smbclient命令（在Linux/macOS上）
      if (process.platform === 'darwin' || process.platform === 'linux') {
        try {
          let authParams = '';
          if (this.config.username) {
            authParams += ` -U ${this.config.username}`;
            if (this.config.password) {
              // 在实际代码中需要正确处理密码中的特殊字符
              authParams += `%${this.config.password}`;
            }
          } else {
            authParams += ' -N'; // 匿名登录
          }
          
          if (this.config.domain) {
            authParams += ` -W ${this.config.domain}`;
          }
          
          const port = this.config.port && this.config.port !== 445 ? ` port=${this.config.port}` : '';
          const command = `smbclient -L ${this.config.ip}${port}${authParams} -g`;
          console.log(`执行命令: ${command}`);
          
          const { stdout } = await execPromise(command);
          
          // 解析输出，获取共享列表
          const shares = stdout
            .split('\n')
            .filter(line => line.includes('Disk|'))
            .map(line => line.split('|')[1]);
          
          if (shares.length > 0) {
            console.log(`通过smbclient找到共享: ${shares.join(', ')}`);
            this.discoveredShares = shares;
            return shares;
          }
        } catch (error) {
          console.error('使用smbclient列出共享失败:', error);
          // 失败时继续尝试其他方法
        }
      }
      
      // 如果smbclient失败或不可用，退回到自动发现方法
      return await this.autoDiscoverShares();
    } catch (error) {
      console.error("列出服务器共享失败:", error);
      throw error;
    }
  }

  // 自动发现服务器上的共享
  public async autoDiscoverShares(): Promise<string[]> {
    if (!this.config || !this.config.ip) {
      throw new Error("Server IP must be specified to discover shares");
    }

    console.log(`尝试发现服务器 ${this.config.ip} 上的共享...`);
    
    try {
      // 首先检查服务器是否可达
      await this.pingServer(this.config.ip, this.config.port || 445);
      
      // 尝试连接常见的共享名称
      const availableShares: string[] = [];
      
      for (const shareName of COMMON_SHARE_NAMES) {
        try {
          // 创建临时客户端尝试连接
          const tempConfig = { ...this.config, sharePath: shareName };
          const tempClient = this.createSMBClient(tempConfig);
          
          // 尝试列出目录
          await tempClient.readdir("");
          
          // 如果没有异常，说明共享存在
          availableShares.push(shareName);
          console.log(`发现共享: ${shareName}`);
          
          // 断开临时连接
          tempClient.disconnect();
        } catch (error: any) {
          // 如果是错误的网络名称，跳过该共享
          if (error.code === 'STATUS_BAD_NETWORK_NAME') {
            continue;
          } else if (error.code === 'STATUS_LOGON_FAILURE') {
            // 如果是认证失败，说明共享存在但需要用户名密码
            availableShares.push(shareName);
            console.log(`发现共享(需要认证): ${shareName}`);
          } else {
            // 其他错误记录下来但继续尝试
            console.log(`尝试连接共享 ${shareName} 时发生错误: ${error.code || error.message}`);
          }
        }
      }
      
      // 更新已发现的共享列表
      this.discoveredShares = availableShares;
      
      return availableShares;
    } catch (error) {
      console.error("自动发现共享失败:", error);
      // 返回一个基于常见共享名称的猜测列表
      return COMMON_SHARE_NAMES;
    }
  }
  
  // 测试服务器端口是否可达
  private async pingServer(ip: string, port: number): Promise<boolean> {
    return new Promise<boolean>((resolve, reject) => {
      const socket = new net.Socket();
      const timeout = 3000; // 3秒超时
      
      socket.setTimeout(timeout);
      socket.on('connect', () => {
        socket.end();
        resolve(true);
      });
      
      socket.on('timeout', () => {
        socket.destroy();
        reject(new Error(`Connection to ${ip}:${port} timed out`));
      });
      
      socket.on('error', (error) => {
        reject(error);
      });
      
      socket.connect(port, ip);
    });
  }

  // 创建新的SMB客户端
  private createSMBClient(config: SambaConfig): any {
    const { ip, port, username, password, domain, sharePath } = config;
    
    if (!ip || ip.trim() === "") {
      throw new Error("Server IP must be specified.");
    }
    
    if (!sharePath || sharePath.trim() === "") {
      throw new Error("Share path must be specified.");
    }
    
    // 构建SMB URL
    // 确保sharePath不以斜杠开头，因为SMB格式为 \\server\share
    const sharePathFormatted = sharePath.replace(/^\/+/, '');
    
    const share = `\\\\${ip}${port && port !== 445 ? `:${port}` : ''}\\${sharePathFormatted}`;
    
    console.log(`Creating SMB client with share: ${share}`);
    
    // 创建SMB客户端
    return new SMB2({
      share: share,
      domain: domain || '',
      username: username || 'guest',
      password: password || '',
      autoCloseTimeout: 0 // 设置为0以手动控制连接关闭
    });
  }

  // 获取SMB2客户端实例
  private getClient(): any {
    if (!this.client && this.config) {
      this.client = this.createSMBClient(this.config);
    }

    return this.client;
  }
  
  // 始终返回true，因为不再依赖系统安装的smbclient
  public isSmbclientAvailable(): boolean {
    return true;
  }

  // 断开连接
  public disconnect(): void {
    if (this.client) {
      this.client.disconnect();
      this.client = null;
    }
  }

  // 列出目录中的文件并自动分类媒体文件
  public async scanMediaFiles(directory: string): Promise<MediaFile[]> {
    if (!this.config) {
      throw new Error("Samba client not configured");
    }

    try {
      const client = this.getClient();
      
      // 处理路径格式
      // 确保目录路径为空字符串（表示共享根目录）或者使用反斜杠格式的路径
      let formattedDirectory = "";
      
      if (directory !== "/" && directory !== "") {
        // 移除前导斜杠并替换正斜杠为反斜杠（SMB使用Windows路径格式）
        formattedDirectory = directory.replace(/^\/+/, '').replace(/\//g, '\\');
      }
      
      console.log(`Scanning media files in directory: "${formattedDirectory}"`);
      
      const files = await client.readdir(formattedDirectory);
      const mediaFiles: MediaFile[] = [];

      for (const fileEntry of files) {
        // 跳过隐藏文件和目录
        let fileName = typeof fileEntry === 'string' ? fileEntry : fileEntry.name;
        
        if (fileName.startsWith('.')) continue;

        // 构建完整路径，注意Windows路径分隔符
        const filePath = formattedDirectory ? `${formattedDirectory}\\${fileName}` : fileName;
        
        try {
          let isDirectory = false;
          
          // 尝试两种方式检测是否是目录
          try {
            // 方法1: 使用stats对象，如果可用
            const stats = await client.stat(filePath);
            
            if (stats) {
              if (typeof stats.isDirectory === 'function') {
                isDirectory = stats.isDirectory();
              } else if (stats.mode) {
                // 使用Unix文件模式位
                const S_IFDIR = 0x4000; // 目录标志位
                isDirectory = (stats.mode & S_IFDIR) === S_IFDIR;
              }
            }
          } catch (statError) {
            // 如果stat方法失败，尝试方法2
            try {
              // 方法2: 尝试读取该路径作为目录
              await client.readdir(filePath);
              // 如果没有抛出异常，说明是一个目录
              isDirectory = true;
            } catch (readdirError: any) {
              // 无法读取为目录，可能是文件或权限问题
              if (readdirError.code === 'STATUS_NOT_A_DIRECTORY') {
                // 确认是文件
                isDirectory = false;
              } else {
                // 对于其他错误，根据文件扩展名推测
                const fileExt = path.extname(fileName).toLowerCase();
                const mediaExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.m4v', '.ass', '.srt'];
                
                // 如果有媒体文件扩展名，认为这是一个文件而不是目录
                isDirectory = !mediaExtensions.includes(fileExt);
              }
            }
          }
          
          if (isDirectory) {
            // 是目录，递归扫描
            try {
              const subMediaFiles = await this.scanMediaFiles(filePath);
              mediaFiles.push(...subMediaFiles);
            } catch (recursiveError) {
              console.error(`Error scanning subdirectory ${filePath}:`, recursiveError);
              // 继续处理其他文件
            }
          } else {
            // 是文件，检查是否是媒体文件
            const fileExt = path.extname(fileName).toLowerCase();
            const mediaExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.m4v'];
            
            if (mediaExtensions.includes(fileExt)) {
              // 基于文件路径和文件名判断类型
              const type = this.determineMediaType(filePath, fileName);
              mediaFiles.push({
                path: filePath,
                fullPath: `${this.config?.sharePath || '未知'} - ${filePath}`,
                type,
                name: path.basename(fileName, fileExt)
              });
              console.log(`Found media file: ${fileName}`);
            }
          }
        } catch (error) {
          console.error(`Error processing file ${filePath}:`, error);
          // 继续处理其他文件
          continue;
        }
      }
      
      return mediaFiles;
    } catch (error: unknown) {
      console.error(`Error scanning media files in ${directory}:`, error);
      throw error;
    }
  }

  // 判断媒体文件类型
  private determineMediaType(filePath: string, fileName: string): 'movie' | 'tv' | 'unknown' {
    const lowerPath = filePath.toLowerCase();
    const lowerName = fileName.toLowerCase();
    
    // 检查路径中是否包含明显的电视剧关键词
    if (lowerPath.includes('tv') || 
        lowerPath.includes('series') || 
        lowerPath.includes('season') || 
        lowerPath.includes('episode')) {
      return 'tv';
    }
    
    // 检查路径中是否包含明显的电影关键词
    if (lowerPath.includes('movie') || 
        lowerPath.includes('film')) {
      return 'movie';
    }
    
    // 检查文件名模式：S01E01, s01e01 等格式
    if (/s\d+e\d+/i.test(lowerName) || 
        /season\s*\d+/i.test(lowerName) || 
        /episode\s*\d+/i.test(lowerName)) {
      return 'tv';
    }
    
    // 其他可能的电视剧模式：包含年份和序号
    if (/\(\d{4}\).*\d+x\d+/i.test(lowerName)) {
      return 'tv';
    }
    
    // 如果文件名包含年份格式 (2020) 但没有季集号标识，可能是电影
    if (/\(\d{4}\)/i.test(lowerName) && !(/\d+x\d+/i.test(lowerName))) {
      return 'movie';
    }
    
    // 无法确定的情况
    return 'unknown';
  }

  // 获取文件内容
  public async readFile(filePath: string): Promise<Buffer> {
    if (!this.config) {
      throw new Error("Samba client not configured");
    }

    try {
      // 处理路径格式 - 使用一致的路径处理逻辑
      let formattedPath = "";
      
      if (filePath !== "/" && filePath !== "") {
        // 移除前导斜杠并替换正斜杠为反斜杠（SMB使用Windows路径格式）
        formattedPath = filePath.replace(/^\/+/, '').replace(/\//g, '\\');
      }
      
      console.log(`Reading file: "${formattedPath}"`);
      
      const client = this.getClient();
      const content = await client.readFile(formattedPath);
      return Buffer.from(content);
    } catch (error: unknown) {
      console.error(`Error reading file ${filePath}:`, error);
      throw error;
    }
  }

  // 将文件下载到本地临时目录
  public async downloadFile(remotePath: string): Promise<string> {
    if (!this.config) {
      throw new Error("Samba client not configured");
    }

    try {
      // 处理路径格式 - 使用一致的路径处理逻辑
      let formattedPath = "";
      
      if (remotePath !== "/" && remotePath !== "") {
        // 移除前导斜杠并替换正斜杠为反斜杠（SMB使用Windows路径格式）
        formattedPath = remotePath.replace(/^\/+/, '').replace(/\//g, '\\');
      }
      
      console.log(`Downloading file: "${formattedPath}"`);
      
      const client = this.getClient();
      const content = await client.readFile(formattedPath);

      // 创建临时文件
      const tempDir = path.join(os.tmpdir(), "open-filmly");
      if (!fs.existsSync(tempDir)) {
        fs.mkdirSync(tempDir, { recursive: true });
      }

      const fileName = path.basename(remotePath);
      const localPath = path.join(tempDir, fileName);

      // 写入文件
      fs.writeFileSync(localPath, content);

      return localPath;
    } catch (error: unknown) {
      console.error(`Error downloading file ${remotePath}:`, error);
      throw error;
    }
  }

  // 按类型获取媒体文件
  public async getMediaByType(directory: string, type: 'movie' | 'tv' | 'unknown'): Promise<MediaFile[]> {
    const allMedia = await this.scanMediaFiles(directory);
    return allMedia.filter(media => media.type === type);
  }

  // 列出目录中的文件
  public async listFiles(directory: string): Promise<string[]> {
    if (!this.config) {
      throw new Error("Samba client not configured");
    }

    try {
      const client = this.getClient();
      
      // 处理路径格式 - 使用与scanMediaFiles相同的逻辑
      let formattedDirectory = "";
      
      if (directory !== "/" && directory !== "") {
        // 移除前导斜杠并替换正斜杠为反斜杠（SMB使用Windows路径格式）
        formattedDirectory = directory.replace(/^\/+/, '').replace(/\//g, '\\');
      }
      
      console.log(`Listing files in directory: "${formattedDirectory}"`);
      
      const files = await client.readdir(formattedDirectory);
      return files;
    } catch (error: unknown) {
      console.error(`Error listing files in ${directory}:`, error);
      throw error;
    }
  }
  
  // 列出可用的共享
  public async listShares(): Promise<string[]> {
    // 如果已经发现过共享，直接返回
    if (this.discoveredShares.length > 0) {
      return this.discoveredShares;
    }
    
    // 尝试直接获取服务器上的所有共享
    if (this.config && this.config.ip) {
      try {
        return await this.listServerShares();
      } catch (error) {
        console.error("直接获取共享列表失败，尝试自动发现...", error);
        return await this.autoDiscoverShares();
      }
    }
    
    // 如果无法自动发现，返回常见共享名称
    return COMMON_SHARE_NAMES;
  }

  // 列出目录中的文件和文件夹
  public async getDirContents(directory: string): Promise<{name: string, isDirectory: boolean, size?: number, modifiedTime?: string}[]> {
    if (!this.config) {
      throw new Error("Samba client not configured");
    }

    try {
      const client = this.getClient();
      
      // 处理路径格式
      let formattedDirectory = "";
      
      if (directory !== "/" && directory !== "") {
        // 移除前导斜杠并替换正斜杠为反斜杠（SMB使用Windows路径格式）
        formattedDirectory = directory.replace(/^\/+/, '').replace(/\//g, '\\');
      }
      
      console.log(`Getting directory contents: "${formattedDirectory}"`);
      
      const files = await client.readdir(formattedDirectory);
      const contentItems = [];
      
      for (const fileEntry of files) {
        // 跳过隐藏文件和目录
        let fileName = typeof fileEntry === 'string' ? fileEntry : fileEntry.name;
        
        if (fileName.startsWith('.')) continue;

        // 构建完整路径，注意Windows路径分隔符
        const filePath = formattedDirectory ? `${formattedDirectory}\\${fileName}` : fileName;
        
        try {
          let isDirectory = false;
          let fileSize: number | undefined = undefined;
          let modifiedTime: string | undefined = undefined;
          
          // 获取文件或目录信息
          try {
            const stats = await client.stat(filePath);
            
            if (stats) {
              // 尝试获取文件大小和修改时间
              if (stats.size !== undefined) {
                fileSize = stats.size;
              }
              
              if (stats.mtime) {
                modifiedTime = new Date(stats.mtime).toISOString();
              }
              
              // 检查是否是目录
              if (typeof stats.isDirectory === 'function') {
                isDirectory = stats.isDirectory();
              } else if (stats.mode) {
                // 使用Unix文件模式位
                const S_IFDIR = 0x4000; // 目录标志位
                isDirectory = (stats.mode & S_IFDIR) === S_IFDIR;
              }
            }
          } catch (statError) {
            // 如果stat方法失败，尝试方法2
            try {
              // 方法2: 尝试读取该路径作为目录
              await client.readdir(filePath);
              // 如果没有异常，说明是一个目录
              isDirectory = true;
            } catch (readdirError: any) {
              // 无法读取为目录，认为是文件
              isDirectory = false;
            }
          }
          
          // 添加到结果列表
          contentItems.push({
            name: fileName,
            isDirectory,
            size: fileSize,
            modifiedTime
          });
          
        } catch (error) {
          console.error(`Error processing file/directory ${filePath}:`, error);
          // 继续处理其他项目
          continue;
        }
      }
      
      // 对结果进行排序：先文件夹，后文件，均按字母顺序
      contentItems.sort((a, b) => {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.localeCompare(b.name);
      });
      
      return contentItems;
    } catch (error: unknown) {
      console.error(`Error getting directory contents in ${directory}:`, error);
      throw error;
    }
  }
} 