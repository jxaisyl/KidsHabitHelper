const cloud = require('wx-server-sdk')
const crypto = require('crypto')

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })
const db = cloud.database()

function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex')
}

exports.main = async (event, context) => {
  // 只支持 HTTP 触发（Flutter 端注册）
  let email, password
  if (typeof event.body === 'string') {
    const params = new URLSearchParams(event.body)
    email = params.get('email')
    password = params.get('password')
  } else if (event.body) {
    email = event.body.email
    password = event.body.password
  }

  if (!email || !password) {
    return { statusCode: 400, error: 'invalid-params', message: '邮箱和密码不能为空' }
  }

  if (password.length < 6) {
    return { statusCode: 400, error: 'weak-password', message: '密码强度太弱' }
  }

  // 检查邮箱是否已注册
  const { data: existing } = await db.collection('users')
    .where({ email }).limit(1).get()

  if (existing.length > 0) {
    return { statusCode: 400, error: 'email-already-in-use', message: '该邮箱已被注册' }
  }

  // 创建用户
  const result = await db.collection('users').add({
    data: {
      email,
      passwordHash: hashPassword(password),
      createdAt: new Date()
    }
  })

  return { token: result._id, uid: result._id }
}
