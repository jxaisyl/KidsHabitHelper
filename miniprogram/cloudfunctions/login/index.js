const cloud = require('wx-server-sdk')
const crypto = require('crypto')

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })
const db = cloud.database()

function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex')
}

// CloudBase HTTP 云函数返回格式
function httpResponse(statusCode, data) {
  return {
    statusCode: statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }
}

exports.main = async (event, context) => {
  // HTTP 触发模式（Flutter 端调用）
  if (event.httpMethod === 'POST') {
    let email, password
    if (typeof event.body === 'string') {
      try {
        const parsed = JSON.parse(event.body)
        email = parsed.email
        password = parsed.password
      } catch (e) {
        const params = new URLSearchParams(event.body)
        email = params.get('email')
        password = params.get('password')
      }
    } else if (event.body) {
      email = event.body.email
      password = event.body.password
    }

    if (!email || !password) {
      return httpResponse(400, { error: 'invalid-params', message: '邮箱和密码不能为空' })
    }

    const { data: users } = await db.collection('users')
      .where({ email }).limit(1).get()

    if (users.length === 0) {
      return httpResponse(401, { error: 'user-not-found', message: '用户不存在' })
    }

    const user = users[0]
    if (user.passwordHash !== hashPassword(password)) {
      return httpResponse(401, { error: 'wrong-password', message: '邮箱或密码错误' })
    }

    return httpResponse(200, { token: user._id, uid: user._id })
  }

  // callFunction 模式（小程序端调用）— 返回 openid
  const wxContext = cloud.getWXContext()
  return {
    openid: wxContext.OPENID,
    appid: wxContext.APPID,
    unionid: wxContext.UNIONID
  }
}
