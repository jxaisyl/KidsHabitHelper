const cloud = require('wx-server-sdk')
const crypto = require('crypto')

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })
const db = cloud.database()

function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex')
}

exports.main = async (event, context) => {
  // Flutter 端通过 invokecloudfunction 调用（event 包含 email/password）
  if (event.email && event.password) {
    const { data: users } = await db.collection('users')
      .where({ email: event.email }).limit(1).get()

    if (users.length === 0) {
      return { error: 'user-not-found', message: '用户不存在' }
    }

    const user = users[0]
    if (user.passwordHash !== hashPassword(event.password)) {
      return { error: 'wrong-password', message: '邮箱或密码错误' }
    }

    return { token: user._id, uid: user._id }
  }

  // 小程序端 callFunction — 返回 openid
  const wxContext = cloud.getWXContext()
  return {
    openid: wxContext.OPENID,
    appid: wxContext.APPID,
    unionid: wxContext.UNIONID
  }
}
