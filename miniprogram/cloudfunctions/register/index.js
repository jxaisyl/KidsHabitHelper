// 云函数 - register
// 处理用户注册，创建用户记录
const cloud = require('wx-server-sdk')

cloud.init({
  env: cloud.DYNAMIC_CURRENT_ENV
})

const db = cloud.database()

exports.main = async (event, context) => {
  const wxContext = cloud.getWXContext()
  const openid = wxContext.OPENID

  const { email, password, nickname } = event

  // 校验必填参数
  if (!email || !password) {
    return {
      code: 400,
      message: '邮箱和密码不能为空'
    }
  }

  // 检查用户是否已存在
  const existUser = await db.collection('users')
    .where({ email: email })
    .get()

  if (existUser.data.length > 0) {
    return {
      code: 409,
      message: '该邮箱已被注册'
    }
  }

  // 创建用户记录
  const result = await db.collection('users').add({
    data: {
      openid: openid,
      email: email,
      password: password,
      nickname: nickname || email.split('@')[0],
      createdAt: db.serverDate(),
      updatedAt: db.serverDate()
    }
  })

  return {
    code: 200,
    message: '注册成功',
    data: {
      uid: result._id,
      openid: openid,
      email: email,
      nickname: nickname || email.split('@')[0]
    }
  }
}
