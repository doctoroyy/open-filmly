/**
 * Go SMB客户端 - 使用编译的Go二进制文件进行SMB操作
 * 比JavaScript库和系统命令都更可靠
 */

import { exec, spawn } from 'child_process';
import { promisify } from 'util';
import * as path from 'path';
import * as fs from 'fs';
import * as os from 'os';

const execPromise = promisify(exec);

interface SambaConfig {
  ip: string
  port?: number
  username?: string
  password?: string
  domain?: string
  sharePath?: string
}

interface GoShareInfo {
  name: string
  type: string
  comment?: string
  permissions?: string
}

interface GoDiscoveryResult {
  host: string
  port: number
  success: boolean
  shares: GoShareInfo[]
  error?: string
  timestamp: string
}

interface GoDirectoryItem {
  name: string
  isDirectory: boolean
  size: number
  modifiedTime: string
}

interface GoDirectoryResult {
  path: string
  success: boolean
  items: GoDirectoryItem[]
  error?: string
}

export class GoSMBClient {
  private config: SambaConfig | null = null;
  private binaryPath: string | null = null;

  constructor() {
    this.initializeBinary();
  }

  /**
   * 初始化Go二进制文件路径
   */
  private initializeBinary(): void {
    const platform = process.platform;
    const arch = process.arch;
    
    // 映射Node.js架构名称到Go架构名称
    const archMap: { [key: string]: string } = {
      'x64': 'amd64',
      'arm64': 'arm64'
    };
    
    const goArch = archMap[arch] || arch;
    
    // 映射平台名称
    const platformMap: { [key: string]: string } = {
      'darwin': 'darwin',
      'win32': 'windows',
      'linux': 'linux'
    };
    
    const goPlatform = platformMap[platform] || platform;
    const extension = platform === 'win32' ? '.exe' : '';
    
    // 构建二进制文件名
    const binaryName = `smb-discover-${goPlatform}-${goArch}${extension}`;
    
    // 查找二进制文件的可能路径
    const possiblePaths = [
      // 开发环境中的路径
      path.join(__dirname, '..', 'tools', 'smb-discover', 'bin', binaryName),
      // 打包后的路径
      path.join(process.resourcesPath, 'bin', binaryName),
      // 当前目录下的bin文件夹
      path.join(process.cwd(), 'bin', binaryName),
      // 工具目录
      path.join(__dirname, '..', 'bin', binaryName)
    ];
    
    for (const binaryPath of possiblePaths) {
      if (fs.existsSync(binaryPath)) {
        this.binaryPath = binaryPath;
        console.log(`[GoSMBClient] Found binary at: ${binaryPath}`);
        
        // 确保二进制文件可执行 (Unix系统)
        if (platform !== 'win32') {
          try {
            fs.chmodSync(binaryPath, 0o755);
          } catch (error) {
            console.warn(`[GoSMBClient] Failed to set executable permission: ${error}`);
          }
        }
        
        return;
      }
    }
    
    console.error(`[GoSMBClient] Binary not found. Searched paths:`, possiblePaths);
    console.error(`[GoSMBClient] Platform: ${platform}, Arch: ${arch}, Expected: ${binaryName}`);
  }

  /**
   * 配置SMB连接参数
   */
  public configure(config: SambaConfig): void {
    this.config = { ...config };
    console.log(`[GoSMBClient] Configured for server: ${config.ip}:${config.port || 445}`);
  }

  /**
   * 检查二进制文件是否可用
   */
  public isBinaryAvailable(): boolean {
    return this.binaryPath !== null && fs.existsSync(this.binaryPath);
  }

  /**
   * 获取二进制文件信息
   */
  public getBinaryInfo(): { available: boolean, path?: string, version?: string } {
    if (!this.isBinaryAvailable()) {
      return { available: false };
    }

    return {
      available: true,
      path: this.binaryPath!,
      version: "1.0.0" // 可以通过执行 --version 获取
    };
  }

  /**
   * 测试服务器连接
   */
  public async testConnection(): Promise<boolean> {
    if (!this.config?.ip) {
      throw new Error("IP address is required");
    }

    if (!this.isBinaryAvailable()) {
      throw new Error("Go SMB binary not found");
    }

    try {
      const args = ['test', this.config.ip];
      if (this.config.port && this.config.port !== 445) {
        args.push(this.config.port.toString());
      }

      const result = await this.executeBinary(args);
      return result.success === true;
    } catch (error: any) {
      console.error('[GoSMBClient] Connection test failed:', error.message);
      return false;
    }
  }

  /**
   * 发现服务器上的真实共享
   */
  public async discoverShares(): Promise<GoShareInfo[]> {
    if (!this.config?.ip) {
      throw new Error("IP address is required");
    }

    if (!this.isBinaryAvailable()) {
      throw new Error("Go SMB binary not found");
    }

    console.log(`[GoSMBClient] Discovering shares on ${this.config.ip}`);

    try {
      const args = [
        'discover',
        this.config.ip,
        this.config.username || 'guest',
        this.config.password || '',
        this.config.domain || 'WORKGROUP'
      ];

      if (this.config.port && this.config.port !== 445) {
        args.push(this.config.port.toString());
      }

      const result = await this.executeBinary(args) as GoDiscoveryResult;

      if (result.success) {
        console.log(`[GoSMBClient] Found ${result.shares.length} shares:`, result.shares.map(s => s.name));
        return result.shares;
      } else {
        throw new Error(result.error || 'Unknown error during share discovery');
      }
    } catch (error: any) {
      console.error('[GoSMBClient] Share discovery failed:', error.message);
      throw error;
    }
  }

  /**
   * 列出指定共享中的目录内容
   */
  public async listDirectory(shareName: string, directory: string = "/"): Promise<GoDirectoryItem[]> {
    if (!this.config?.ip) {
      throw new Error("IP address is required");
    }

    if (!this.isBinaryAvailable()) {
      throw new Error("Go SMB binary not found");
    }

    console.log(`[GoSMBClient] Listing directory: ${shareName}/${directory}`);

    try {
      const args = [
        'list',
        this.config.ip,
        shareName,
        directory === "/" ? "/" : directory,
        this.config.username || 'guest',
        this.config.password || '',
        this.config.domain || 'WORKGROUP'
      ];

      if (this.config.port && this.config.port !== 445) {
        args.push(this.config.port.toString());
      }

      const result = await this.executeBinary(args) as GoDirectoryResult;

      if (result.success) {
        console.log(`[GoSMBClient] Found ${result.items.length} items in ${shareName}/${directory}`);
        return result.items;
      } else {
        throw new Error(result.error || 'Unknown error during directory listing');
      }
    } catch (error: any) {
      console.error('[GoSMBClient] Directory listing failed:', error.message);
      throw error;
    }
  }

  /**
   * 执行Go二进制文件并解析JSON响应
   */
  private async executeBinary(args: string[]): Promise<any> {
    if (!this.binaryPath) {
      throw new Error("Go SMB binary not found");
    }

    return new Promise((resolve, reject) => {
      const process = spawn(this.binaryPath!, args, {
        stdio: ['pipe', 'pipe', 'pipe']
      });

      let stdout = '';
      let stderr = '';

      process.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      process.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      process.on('close', (code) => {
        if (code !== 0) {
          const errorMsg = stderr || `Process exited with code ${code}`;
          console.error(`[GoSMBClient] Binary execution failed: ${errorMsg}`);
          reject(new Error(errorMsg));
          return;
        }

        try {
          const result = JSON.parse(stdout);
          resolve(result);
        } catch (parseError) {
          console.error(`[GoSMBClient] Failed to parse JSON response: ${parseError}`);
          console.error(`[GoSMBClient] Raw output: ${stdout}`);
          reject(new Error(`Invalid JSON response: ${parseError}`));
        }
      });

      process.on('error', (error) => {
        console.error(`[GoSMBClient] Failed to start binary: ${error}`);
        reject(error);
      });

      // 设置超时
      const timeout = setTimeout(() => {
        process.kill();
        reject(new Error('Binary execution timeout'));
      }, 30000); // 30秒超时

      process.on('close', () => {
        clearTimeout(timeout);
      });
    });
  }

  /**
   * 获取详细的系统和二进制信息用于调试
   */
  public async getSystemInfo(): Promise<any> {
    const info = {
      platform: process.platform,
      arch: process.arch,
      nodeVersion: process.version,
      binaryInfo: this.getBinaryInfo(),
      config: this.config,
      searchPaths: [
        path.join(__dirname, '..', 'tools', 'smb-discover', 'bin'),
        path.join(process.resourcesPath, 'bin'),
        path.join(process.cwd(), 'bin'),
        path.join(__dirname, '..', 'bin')
      ]
    };

    console.log('[GoSMBClient] System info:', JSON.stringify(info, null, 2));
    return info;
  }

  /**
   * 读取文件内容 - 用于媒体代理服务器
   */
  public async readFile(filePath: string): Promise<Buffer> {
    if (!this.config?.ip) {
      throw new Error("IP address is required");
    }
    if (!this.isBinaryAvailable()) {
      throw new Error("Go SMB binary not found");
    }

    // Parse file path to extract share and relative path
    const pathParts = filePath.split('/').filter(Boolean);
    if (pathParts.length === 0) {
      throw new Error("Invalid file path");
    }
    
    const shareName = pathParts[0];
    const relativeFilePath = pathParts.length > 1 ? pathParts.slice(1).join('/') : '';
    
    console.log(`[GoSMBClient] Reading file: ${shareName}/${relativeFilePath}`);
    
    try {
      const args = [
        'read',
        this.config.ip,
        shareName,
        relativeFilePath,
        this.config.username || 'guest',
        this.config.password || '',
        this.config.domain || 'WORKGROUP'
      ];

      const result = await this.executeBinary(args);
      
      if (result.success && result.data) {
        // Convert base64 data to Buffer
        return Buffer.from(result.data, 'base64');
      } else {
        throw new Error(result.error || 'Failed to read file');
      }
    } catch (error: any) {
      console.error(`[GoSMBClient] Error reading file ${filePath}:`, error);
      throw error;
    }
  }

  /**
   * 扫描媒体文件 - 用于自动扫描管理器
   */
  public async scanMediaFiles(directory: string): Promise<any[]> {
    if (!this.config?.ip) {
      throw new Error("IP address is required");
    }

    console.log(`[GoSMBClient] Scanning media files in: ${directory}`);
    
    const mediaFiles: any[] = [];
    
    try {
      // Parse directory path
      const pathParts = directory.split('/').filter(Boolean);
      if (pathParts.length === 0) {
        throw new Error("Invalid directory path");
      }
      
      const shareName = pathParts[0];
      const relativePath = pathParts.length > 1 ? '/' + pathParts.slice(1).join('/') : '/';
      
      // Get directory contents
      const items = await this.listDirectory(shareName, relativePath);
      
      for (const item of items) {
        if (item.isDirectory) {
          // Recursively scan subdirectories
          const subPath = `${directory}/${item.name}`;
          try {
            const subFiles = await this.scanMediaFiles(subPath);
            mediaFiles.push(...subFiles);
          } catch (error) {
            console.error(`Error scanning subdirectory ${subPath}:`, error);
          }
        } else {
          // Check if it's a media file
          const fileExt = path.extname(item.name).toLowerCase();
          const mediaExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.m4v'];
          
          if (mediaExtensions.includes(fileExt)) {
            const type = this.determineMediaType(`${directory}/${item.name}`, item.name);
            mediaFiles.push({
              path: `${directory}/${item.name}`,
              fullPath: `${directory}/${item.name}`,
              type,
              name: path.basename(item.name, fileExt)
            });
          }
        }
      }
      
      return mediaFiles;
    } catch (error: any) {
      console.error(`[GoSMBClient] Error scanning media files in ${directory}:`, error);
      throw error;
    }
  }

  /**
   * 判断媒体文件类型
   */
  private determineMediaType(filePath: string, fileName: string): 'movie' | 'tv' | 'unknown' {
    const lowerPath = filePath.toLowerCase();
    const lowerName = fileName.toLowerCase();
    
    // Check for TV show keywords in path
    if (lowerPath.includes('tv') || 
        lowerPath.includes('series') || 
        lowerPath.includes('season') || 
        lowerPath.includes('episode')) {
      return 'tv';
    }
    
    // Check for movie keywords in path
    if (lowerPath.includes('movie') || 
        lowerPath.includes('film')) {
      return 'movie';
    }
    
    // Check for TV show patterns in filename: S01E01, s01e01 etc.
    if (/s\d+e\d+/i.test(lowerName) || 
        /season\s*\d+/i.test(lowerName) || 
        /episode\s*\d+/i.test(lowerName)) {
      return 'tv';
    }
    
    // Other TV show patterns: containing year and episode numbers
    if (/\(\d{4}\).*\d+x\d+/i.test(lowerName)) {
      return 'tv';
    }
    
    // If filename contains year (2020) but no season/episode indicators, likely a movie
    if (/\(\d{4}\)/i.test(lowerName) && !(/\d+x\d+/i.test(lowerName))) {
      return 'movie';
    }
    
    return 'unknown';
  }

  /**
   * 获取配置状态
   */
  public getConfigurationStatus(): { configured: boolean, hasSharePath: boolean, details: any } {
    return {
      configured: !!this.config,
      hasSharePath: !!(this.config?.sharePath && this.config.sharePath.trim() !== ''),
      details: {
        ip: this.config?.ip || 'not set',
        sharePath: this.config?.sharePath || 'not set',
        username: this.config?.username || 'not set',
        hasPassword: !!(this.config?.password && this.config.password.trim() !== '')
      }
    };
  }

  /**
   * 断开连接 - 兼容性方法
   */
  public disconnect(): void {
    // Go二进制客户端是无状态的，所以不需要断开连接
    console.log('[GoSMBClient] Disconnect called (no-op for binary client)');
  }
}