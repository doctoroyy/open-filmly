// Cloudflare Workers API for Open Filmly Hash Service
// 部署到 Cloudflare Workers，提供免费的文件hash匹配服务

// 配置
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, User-Agent',
}

// 主处理函数
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url)
    const path = url.pathname

    // 处理 CORS 预检请求
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 200,
        headers: CORS_HEADERS
      })
    }

    try {
      // 路由处理
      if (path === '/api/query-hash' && request.method === 'GET') {
        return handleQueryHash(request, env)
      }
      
      if (path === '/api/submit-hash' && request.method === 'POST') {
        return handleSubmitHash(request, env)
      }
      
      if (path.startsWith('/api/query-hash/') && request.method === 'GET') {
        const fileHash = path.split('/').pop()
        return handleQueryHashById(fileHash, env)
      }
      
      if (path === '/api/stats' && request.method === 'GET') {
        return handleGetStats(env)
      }

      // 健康检查
      if (path === '/health') {
        return new Response(JSON.stringify({ 
          status: 'healthy', 
          timestamp: new Date().toISOString(),
          service: 'filmly-hash-api'
        }), {
          headers: { 
            'Content-Type': 'application/json',
            ...CORS_HEADERS 
          }
        })
      }

      return new Response('Not Found', { 
        status: 404,
        headers: CORS_HEADERS 
      })
    } catch (error) {
      console.error('Error handling request:', error)
      return new Response(JSON.stringify({ 
        error: 'Internal Server Error',
        message: error.message 
      }), {
        status: 500,
        headers: { 
          'Content-Type': 'application/json',
          ...CORS_HEADERS 
        }
      })
    }
  }
}

// 查询文件hash对应的媒体信息
async function handleQueryHashById(fileHash, env) {
  if (!fileHash || fileHash.length !== 32) {
    return new Response(JSON.stringify({ 
      error: 'Invalid hash format' 
    }), {
      status: 400,
      headers: { 
        'Content-Type': 'application/json',
        ...CORS_HEADERS 
      }
    })
  }

  try {
    // 查询 D1 数据库
    const result = await env.DB.prepare(`
      SELECT 
        file_hash,
        media_data,
        confidence,
        submission_count,
        last_updated,
        created_at
      FROM hash_matches 
      WHERE file_hash = ? 
      ORDER BY confidence DESC, submission_count DESC
      LIMIT 1
    `).bind(fileHash).first()

    if (result) {
      // 增加查询计数
      await env.DB.prepare(`
        UPDATE hash_matches 
        SET query_count = query_count + 1,
            last_queried = datetime('now')
        WHERE file_hash = ?
      `).bind(fileHash).run()

      return new Response(JSON.stringify({
        matched: true,
        fileHash: result.file_hash,
        mediaData: JSON.parse(result.media_data),
        confidence: result.confidence,
        stats: {
          submissionCount: result.submission_count,
          lastUpdated: result.last_updated
        }
      }), {
        headers: { 
          'Content-Type': 'application/json',
          ...CORS_HEADERS 
        }
      })
    }

    return new Response(JSON.stringify({
      matched: false,
      fileHash: fileHash
    }), {
      status: 404,
      headers: { 
        'Content-Type': 'application/json',
        ...CORS_HEADERS 
      }
    })
  } catch (error) {
    console.error('Database query error:', error)
    return new Response(JSON.stringify({ 
      error: 'Database query failed' 
    }), {
      status: 500,
      headers: { 
        'Content-Type': 'application/json',
        ...CORS_HEADERS 
      }
    })
  }
}

// 提交文件hash和媒体信息
async function handleSubmitHash(request, env) {
  try {
    const data = await request.json()
    
    // 验证数据
    if (!data.fileHash || !data.mediaData || !data.confidence) {
      return new Response(JSON.stringify({ 
        error: 'Missing required fields' 
      }), {
        status: 400,
        headers: { 
          'Content-Type': 'application/json',
          ...CORS_HEADERS 
        }
      })
    }

    // 验证hash格式
    if (!/^[a-f0-9]{32}$/i.test(data.fileHash)) {
      return new Response(JSON.stringify({ 
        error: 'Invalid hash format' 
      }), {
        status: 400,
        headers: { 
          'Content-Type': 'application/json',
          ...CORS_HEADERS 
        }
      })
    }

    // 验证置信度
    if (data.confidence < 0.5 || data.confidence > 1.0) {
      return new Response(JSON.stringify({ 
        error: 'Invalid confidence value' 
      }), {
        status: 400,
        headers: { 
          'Content-Type': 'application/json',
          ...CORS_HEADERS 
        }
      })
    }

    const userAgent = request.headers.get('User-Agent') || 'unknown'
    const clientIP = request.headers.get('CF-Connecting-IP') || 'unknown'

    // 检查是否已存在记录
    const existing = await env.DB.prepare(`
      SELECT file_hash, confidence, submission_count 
      FROM hash_matches 
      WHERE file_hash = ?
    `).bind(data.fileHash).first()

    if (existing) {
      // 如果新提交的置信度更高，或者置信度相近但提供更多信息，则更新
      const shouldUpdate = (
        data.confidence > existing.confidence + 0.1 ||
        (Math.abs(data.confidence - existing.confidence) < 0.1 && 
         Object.keys(data.mediaData).length > 3)
      )

      if (shouldUpdate) {
        await env.DB.prepare(`
          UPDATE hash_matches 
          SET 
            media_data = ?,
            confidence = ?,
            submission_count = submission_count + 1,
            last_updated = datetime('now'),
            last_user_agent = ?
          WHERE file_hash = ?
        `).bind(
          JSON.stringify(data.mediaData),
          data.confidence,
          userAgent,
          data.fileHash
        ).run()

        // 记录提交历史
        await recordSubmission(env, data, userAgent, clientIP, 'updated')

        return new Response(JSON.stringify({ 
          success: true,
          action: 'updated',
          message: 'Hash data updated successfully'
        }), {
          headers: { 
            'Content-Type': 'application/json',
            ...CORS_HEADERS 
          }
        })
      } else {
        // 只增加提交计数
        await env.DB.prepare(`
          UPDATE hash_matches 
          SET submission_count = submission_count + 1
          WHERE file_hash = ?
        `).bind(data.fileHash).run()

        return new Response(JSON.stringify({ 
          success: true,
          action: 'acknowledged',
          message: 'Submission acknowledged, existing data retained'
        }), {
          headers: { 
            'Content-Type': 'application/json',
            ...CORS_HEADERS 
          }
        })
      }
    } else {
      // 插入新记录
      await env.DB.prepare(`
        INSERT INTO hash_matches (
          file_hash,
          media_data,
          confidence,
          submission_count,
          query_count,
          created_at,
          last_updated,
          last_user_agent
        ) VALUES (?, ?, ?, 1, 0, datetime('now'), datetime('now'), ?)
      `).bind(
        data.fileHash,
        JSON.stringify(data.mediaData),
        data.confidence,
        userAgent
      ).run()

      // 记录提交历史
      await recordSubmission(env, data, userAgent, clientIP, 'created')

      return new Response(JSON.stringify({ 
        success: true,
        action: 'created',
        message: 'Hash data submitted successfully'
      }), {
        status: 201,
        headers: { 
          'Content-Type': 'application/json',
          ...CORS_HEADERS 
        }
      })
    }
  } catch (error) {
    console.error('Submit hash error:', error)
    return new Response(JSON.stringify({ 
      error: 'Failed to submit hash data',
      message: error.message 
    }), {
      status: 500,
      headers: { 
        'Content-Type': 'application/json',
        ...CORS_HEADERS 
      }
    })
  }
}

// 获取服务统计信息
async function handleGetStats(env) {
  try {
    const stats = await env.DB.prepare(`
      SELECT 
        COUNT(*) as total_hashes,
        AVG(confidence) as avg_confidence,
        SUM(submission_count) as total_submissions,
        SUM(query_count) as total_queries,
        COUNT(CASE WHEN created_at >= datetime('now', '-7 days') THEN 1 END) as recent_submissions
      FROM hash_matches
    `).first()

    const topContributors = await env.DB.prepare(`
      SELECT 
        substr(last_user_agent, 1, 20) as user_agent_prefix,
        COUNT(*) as contribution_count
      FROM hash_matches
      GROUP BY last_user_agent
      ORDER BY contribution_count DESC
      LIMIT 5
    `).all()

    return new Response(JSON.stringify({
      success: true,
      stats: {
        totalHashes: stats.total_hashes,
        averageConfidence: Math.round(stats.avg_confidence * 100) / 100,
        totalSubmissions: stats.total_submissions,
        totalQueries: stats.total_queries,
        recentSubmissions: stats.recent_submissions,
        topContributors: topContributors.results
      },
      lastUpdated: new Date().toISOString()
    }), {
      headers: { 
        'Content-Type': 'application/json',
        ...CORS_HEADERS 
      }
    })
  } catch (error) {
    console.error('Stats query error:', error)
    return new Response(JSON.stringify({ 
      error: 'Failed to retrieve stats' 
    }), {
      status: 500,
      headers: { 
        'Content-Type': 'application/json',
        ...CORS_HEADERS 
      }
    })
  }
}

// 记录提交历史（用于审计和反滥用）
async function recordSubmission(env, data, userAgent, clientIP, action) {
  try {
    await env.DB.prepare(`
      INSERT INTO submission_history (
        file_hash,
        media_title,
        media_type,
        confidence,
        action,
        user_agent,
        client_ip,
        submitted_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))
    `).bind(
      data.fileHash,
      data.mediaData.title,
      data.mediaData.type,
      data.confidence,
      action,
      userAgent,
      clientIP
    ).run()
  } catch (error) {
    console.error('Failed to record submission history:', error)
    // 不影响主要功能，只记录错误
  }
}

/*
数据库架构 (D1):

-- 主要的hash匹配表
CREATE TABLE hash_matches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_hash TEXT UNIQUE NOT NULL,
  media_data TEXT NOT NULL,  -- JSON格式的媒体信息
  confidence REAL NOT NULL,
  submission_count INTEGER DEFAULT 1,
  query_count INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  last_updated TEXT NOT NULL,
  last_queried TEXT,
  last_user_agent TEXT
);

-- 提交历史表（用于审计）
CREATE TABLE submission_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_hash TEXT NOT NULL,
  media_title TEXT,
  media_type TEXT,
  confidence REAL,
  action TEXT,  -- created, updated, acknowledged
  user_agent TEXT,
  client_ip TEXT,
  submitted_at TEXT NOT NULL
);

-- 创建索引
CREATE INDEX idx_hash_matches_file_hash ON hash_matches(file_hash);
CREATE INDEX idx_hash_matches_confidence ON hash_matches(confidence DESC);
CREATE INDEX idx_submission_history_hash ON submission_history(file_hash);
CREATE INDEX idx_submission_history_date ON submission_history(submitted_at);
*/