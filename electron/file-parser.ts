interface ParsedFileName {
  title: string
  year?: string
  resolution?: string
  source?: string
  season?: number
  episode?: number
}

export function parseFileName(fileName: string): ParsedFileName {
  // 移除文件扩展名
  const nameWithoutExt = fileName.replace(/\.[^/.]+$/, "")

  // 尝试提取季和集信息（如S01E02、第1季第2集）
  const seasonEpisodeMatch = nameWithoutExt.match(/[Ss](\d{1,2})[Ee](\d{1,2})|第(\d{1,2})季.*?第(\d{1,2})集/)
  const season = seasonEpisodeMatch ? parseInt(seasonEpisodeMatch[1] || seasonEpisodeMatch[3]) : undefined
  const episode = seasonEpisodeMatch ? parseInt(seasonEpisodeMatch[2] || seasonEpisodeMatch[4]) : undefined

  // 尝试提取年份（支持更多格式）
  const yearMatch = nameWithoutExt.match(/[.[(（]?(19\d{2}|20\d{2})[)）\].]?/)
  const year = yearMatch ? yearMatch[1] : undefined

  // 尝试提取分辨率（支持更多格式）
  const resolutionMatch = nameWithoutExt.match(/[.[(（]?(1080[pi]|720[pi]|2160[pi]|4K|UHD|HD|超清)[)）\].]?/i)
  const resolution = resolutionMatch ? resolutionMatch[1] : undefined

  // 尝试提取来源（支持更多格式）
  const sourceMatch = nameWithoutExt.match(/[.[(（]?(BluRay|Blu-Ray|WEB-DL|HDTV|DVDRip|BDRip|HDRip|WEBRIP)[)）\].]?/i)
  const source = sourceMatch ? sourceMatch[1] : undefined

  // 清理标题
  let title = nameWithoutExt

  // 从标题中移除年份、分辨率和来源（如果存在）
  if (year) {
    title = title.replace(new RegExp(`[.[(（]?${year}[)）\\].]?`), " ")
  }
  if (resolution) {
    title = title.replace(new RegExp(`[.[(（]?${resolution}[)）\\].]?`, "i"), " ")
  }
  if (source) {
    title = title.replace(new RegExp(`[.[(（]?${source}[)）\\].]?`, "i"), " ")
  }
  if (seasonEpisodeMatch) {
    title = title.replace(seasonEpisodeMatch[0], " ")
  }

  // 移除常见分隔符并清理
  title = title
    .replace(/[._]/g, " ")                 // 替换点和下划线为空格
    .replace(/\[\s*\]/g, " ")             // 移除空方括号
    .replace(/【.*?】/g, " ")             // 移除【】中的内容
    .replace(/[「」『』]/g, " ")          // 移除日式引号
    .replace(/-\s*[^-]*$/, " ")           // 移除最后一个破折号后的内容（通常是发布组信息）
    .replace(/\([^)]*\)/g, " ")           // 移除括号中的内容
    .replace(/\s+/g, " ")                 // 合并多个空格
    .trim()

  // 如果标题以破折号开头或结尾，清理它
  title = title.replace(/^-+|-+$/g, "").trim()

  return {
    title,
    year,
    resolution,
    source,
    season,
    episode
  }
}

