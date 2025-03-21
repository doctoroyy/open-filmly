import { type NextRequest, NextResponse } from "next/server"

// 获取Samba配置
export async function GET(request: NextRequest) {
  return NextResponse.json({
    ip: process.env.SAMBA_IP || "192.168.31.100",
    moviePath: process.env.SAMBA_MOVIE_PATH || "movies",
    tvPath: process.env.SAMBA_TV_PATH || "tv",
  })
}

// 更新Samba配置
export async function POST(request: NextRequest) {
  try {
    const data = await request.json()

    // 在实际应用中，您需要:
    // 1. 验证输入数据
    // 2. 更新环境变量或配置文件
    // 3. 如有必要，重启应用

    // 为了演示目的，我们只返回成功
    return NextResponse.json({ success: true, message: "Configuration updated" })
  } catch (error) {
    console.error("Error updating configuration:", error)
    return NextResponse.json({ error: "Failed to update configuration" }, { status: 500 })
  }
}

