const cloud = require('wx-server-sdk')
const https = require('https')
cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })
const db = cloud.database()
const _ = db.command

// ===== 配置 =====
// APPID 公开可见（在小程序里就能拿到），可以硬编码
// SECRET 必须保密！部署前在云函数环境变量里配置 WX_APP_SECRET
//   云开发控制台 → 云函数 → timer-notify → 环境变量 → 添加 WX_APP_SECRET
// 本地调试时可以临时写回真实 Secret，但不要 commit
const APPID = 'wx96ca310e00f3f1f0'
const SECRET = process.env.WX_APP_SECRET || 'YOUR_APP_SECRET_HERE'
const TEMPLATE_ID = '5nNhcgrDVmqgipdKeZqfHH92nzqYchJK5T6oLG99Z00'

// 微信 time 类型字段要求 YYYY-MM-DD HH:mm:ss 格式（不接受 ISO）
function formatTime(iso) {
  var d = new Date(iso)
  function p(n) { return n < 10 ? '0' + n : '' + n }
  return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()) + ' ' + p(d.getHours()) + ':' + p(d.getMinutes()) + ':' + p(d.getSeconds())
}

// 简单的 HTTPS GET/POST 工具（用内置 https 模块，不需要额外依赖）
function httpJson(method, urlStr, body) {
  return new Promise(function (resolve, reject) {
    var u = new URL(urlStr)
    var bodyStr = body ? JSON.stringify(body) : null
    var options = {
      hostname: u.hostname,
      path: u.pathname + u.search,
      method: method,
      headers: { 'Content-Type': 'application/json' }
    }
    // POST 必须设置 Content-Length，否则微信会返回空响应
    if (bodyStr) {
      options.headers['Content-Length'] = Buffer.byteLength(bodyStr)
    }
    var req = https.request(options, function (res) {
      var chunks = []
      res.on('data', function (c) { chunks.push(c) })
      res.on('end', function () {
        var raw = Buffer.concat(chunks).toString('utf8')
        console.log('HTTP', method, u.pathname, 'status:', res.statusCode, '响应:', raw)
        if (!raw) {
          reject(new Error('空响应 status=' + res.statusCode))
          return
        }
        try {
          resolve(JSON.parse(raw))
        } catch (e) {
          reject(new Error('JSON 解析失败 raw=' + raw))
        }
      })
    })
    req.on('error', reject)
    if (bodyStr) req.write(bodyStr)
    req.end()
  })
}

// access_token 缓存（有效期 2 小时，提前 5 分钟刷新）
let cachedToken = null
let tokenExpireAt = 0
async function getAccessToken() {
  if (cachedToken && Date.now() < tokenExpireAt) return cachedToken
  var url = 'https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=' + APPID + '&secret=' + SECRET
  var res = await httpJson('GET', url, null)
  if (!res.access_token) {
    throw new Error('获取 access_token 失败: ' + JSON.stringify(res))
  }
  cachedToken = res.access_token
  tokenExpireAt = Date.now() + (res.expires_in - 300) * 1000
  return cachedToken
}

exports.main = async (event, context) => {
  const now = new Date()
  const expireBefore = new Date(now.getTime() - 25 * 3600 * 1000)
  console.log('timer-notify 触发, 当前时间:', now.toISOString(), 'event:', JSON.stringify(event))

  try {
    // 1. 拿 access_token
    const token = await getAccessToken()
    console.log('access_token 获取成功, 长度:', token.length)

    // 2. 扫描到期未通知的 timer
    const { data: due } = await db.collection('timers')
      .where({
        fireAt: _.lte(now.toISOString()),
        notified: false
      })
      .limit(100)
      .get()
    console.log('扫描到到期未通知 timer 数量:', due.length)

    // 3. 逐条发送订阅消息（HTTP API）
    let sentCount = 0
    let failCount = 0
    for (const t of due) {
      try {
        var sendUrl = 'https://api.weixin.qq.com/cgi-bin/message/subscribe/send?access_token=' + token
        var sendBody = {
          touser: t.userId,
          template_id: TEMPLATE_ID,
          page: 'pages/timer/timer?childId=' + t.childId,
          miniprogram_state: 'developer', // 开发版，正式上线改 'formal'
          lang: 'zh_CN',
          data: {
            thing1: { value: String(t.childName).slice(0, 20) },
            thing2: { value: String(t.ruleName).slice(0, 20) },
            time3: { value: formatTime(t.fireAt) }
          }
        }
        var sendRes = await httpJson('POST', sendUrl, sendBody)
        if (sendRes.errcode === 0) {
          sentCount++
          await db.collection('timers').doc(t._id).update({ data: { notified: true } })
        } else {
          failCount++
          console.error('send failed for timer', t._id, 'errcode:', sendRes.errcode, 'errmsg:', sendRes.errmsg)
          // 这些错误码标记为已通知避免无限重试
          // 43101 用户未订阅/拒绝；40037 模板ID错；41030 页面路径错；47003 模板参数不匹配；40013 AppID无效
          if ([43101, 40037, 41030, 47003, 40013, 200013].indexOf(sendRes.errcode) >= 0) {
            await db.collection('timers').doc(t._id).update({ data: { notified: true } })
          }
        }
      } catch (err) {
        failCount++
        console.error('send exception for timer', t._id, err)
      }
    }
    console.log('发送完成: 成功', sentCount, '失败', failCount)

    // 4. 清理超过 25 小时的记录
    const { stats: rmStats } = await db.collection('timers')
      .where({ createdAt: _.lt(expireBefore.toISOString()) })
      .remove()
    console.log('清理过期记录:', rmStats.removed)

    return { sent: sentCount, failed: failCount, scanned: due.length }
  } catch (err) {
    console.error('timer-notify error:', err)
    return { error: 'internal-error', message: String(err) }
  }
}
