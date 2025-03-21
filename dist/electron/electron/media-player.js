"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.MediaPlayer = void 0;
const child_process_1 = require("child_process");
const util_1 = require("util");
const os = __importStar(require("os"));
const execAsync = (0, util_1.promisify)(child_process_1.exec);
class MediaPlayer {
    // 播放媒体文件
    async play(filePath) {
        try {
            const platform = os.platform();
            // 根据操作系统选择播放方式
            if (platform === "win32") {
                // Windows
                await execAsync(`start "" "${filePath}"`);
            }
            else if (platform === "darwin") {
                // macOS
                await execAsync(`open "${filePath}"`);
            }
            else if (platform === "linux") {
                // Linux
                await execAsync(`xdg-open "${filePath}"`);
            }
            else {
                throw new Error(`Unsupported platform: ${platform}`);
            }
        }
        catch (error) {
            console.error(`Error playing file ${filePath}:`, error);
            throw error;
        }
    }
    // 使用VLC播放媒体文件
    async playWithVlc(filePath) {
        try {
            const platform = os.platform();
            // 根据操作系统选择VLC路径
            let vlcCommand = "";
            if (platform === "win32") {
                // Windows
                vlcCommand = `"C:\\Program Files\\VideoLAN\\VLC\\vlc.exe" "${filePath}"`;
            }
            else if (platform === "darwin") {
                // macOS
                vlcCommand = `/Applications/VLC.app/Contents/MacOS/VLC "${filePath}"`;
            }
            else if (platform === "linux") {
                // Linux
                vlcCommand = `vlc "${filePath}"`;
            }
            else {
                throw new Error(`Unsupported platform: ${platform}`);
            }
            await execAsync(vlcCommand);
        }
        catch (error) {
            console.error(`Error playing file with VLC ${filePath}:`, error);
            throw error;
        }
    }
}
exports.MediaPlayer = MediaPlayer;
//# sourceMappingURL=media-player.js.map