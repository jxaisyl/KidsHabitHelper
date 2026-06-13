const cloud = require('wx-server-sdk')
const crypto = require('crypto')

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })
const db = cloud.database()

function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex')
}

exports.main = async (event, context) => {
  const email = event.email
  const password = event.password

  if (!email || !password) {
    return { error: 'invalid-params', message: '邮箱和密码不能为空' }
  }

  if (password.length < 6) {
    return { error: 'weak-password', message: '密码强度太弱' }
  }

  const { data: existing } = await db.collection('users')
    .where({ email }).limit(1).get()

  if (existing.length > 0) {
    return { error: 'email-already-in-use', message: '该邮箱已被注册' }
  }

  const result = await db.collection('users').add({
    data: {
      email,
      passwordHash: hashPassword(password),
      createdAt: new Date()
    }
  })

  return { token: result._id, uid: result._id }
}
