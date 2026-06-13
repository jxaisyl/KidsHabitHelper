const cloud = require('wx-server-sdk')
const crypto = require('crypto')

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })
const db = cloud.database()

function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex')
}

function httpResponse(statusCode, data) {
  return {
    statusCode: statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }
}

exports.main = async (event, context) => {
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

  if (password.length < 6) {
    return httpResponse(400, { error: 'weak-password', message: '密码强度太弱' })
  }

  const { data: existing } = await db.collection('users')
    .where({ email }).limit(1).get()

  if (existing.length > 0) {
    return httpResponse(400, { error: 'email-already-in-use', message: '该邮箱已被注册' })
  }

  const result = await db.collection('users').add({
    data: {
      email,
      passwordHash: hashPassword(password),
      createdAt: new Date()
    }
  })

  return httpResponse(200, { token: result._id, uid: result._id })
}
