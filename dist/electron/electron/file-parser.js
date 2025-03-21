"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseFileName = parseFileName;
function parseFileName(fileName) {
    // 移除文件扩展名
    const nameWithoutExt = fileName.replace(/\.[^/.]+$/, "");
    // 中文媒体文件的常见模式
    // 电影名.2023.1080p.WEB-DL.H264.AAC-GROUP
    // 电影名 (2023) [1080p]
    // [电影名][2023][1080p]
    // 尝试提取年份（括号或方括号中的4位数字，或点后面的4位数字）
    const yearMatch = nameWithoutExt.match(/[.[(]?(19\d{2}|20\d{2})[)\].]?/);
    const year = yearMatch ? yearMatch[1] : undefined;
    // 尝试提取分辨率（如1080p、720p、4K）
    const resolutionMatch = nameWithoutExt.match(/[.[(]?(1080p|720p|2160p|4K)[)\].]?/i);
    const resolution = resolutionMatch ? resolutionMatch[1] : undefined;
    // 尝试提取来源（如BluRay、WEB-DL）
    const sourceMatch = nameWithoutExt.match(/[.[(]?(BluRay|WEB-DL|HDTV|DVDRip)[)\].]?/i);
    const source = sourceMatch ? sourceMatch[1] : undefined;
    // 清理标题
    let title = nameWithoutExt;
    // 从标题中移除年份、分辨率和来源（如果存在）
    if (year) {
        title = title.replace(new RegExp(`[.[(]?${year}[)\\].]?`), " ");
    }
    if (resolution) {
        title = title.replace(new RegExp(`[.[(]?${resolution}[)\\].]?`, "i"), " ");
    }
    if (source) {
        title = title.replace(new RegExp(`[.[(]?${source}[)\\].]?`, "i"), " ");
    }
    // 移除常见分隔符并清理
    title = title
        .replace(/[._]/g, " ")
        .replace(/\[\s*\]/g, " ")
        .replace(/$$\s*$$/g, " ")
        .replace(/\s+/g, " ")
        .trim();
    return {
        title,
        year,
        resolution,
        source,
    };
}
//# sourceMappingURL=file-parser.js.map