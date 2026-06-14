const cloud = require('wx-server-sdk')
cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })
const db = cloud.database()
const _ = db.command

// 部署前替换为小程序后台申请的订阅消息模板 ID
const TEMPLATE_ID = 'REPLACE_WITH_TEMPLATE_ID'

exports.main = async (event, context) => {
  const now = new Date()
  const expireBefore = new Date(now.getTime() - 25 * 3600 * 1000)

  try {
    // 1. 扫描到期未通知的 timer
    const { data: due } = await db.collection('timers')
      .where({
        fireAt: _.lte(now.toISOString()),
        notified: false
      })
      .limit(100)
      .get()

    // 2. 逐条发送订阅消息
    for (const t of due) {
      try {
        await cloud.openapi.subscribeMessage.send({
          touser: t.userId,
          templateId: TEMPLATE_ID,
          // page: 点击消息跳转到计时器页
          page: 'pages/timer/timer?childId=' + t.childId,
          data: {
            // 字段名必须与申请的模板一致；以下为常见命名，部署前对齐
            thing1: { value: String(t.childName).slice(0, 20) },
            thing2: { value: String(t.ruleName).slice(0, 20) },
            time3: { value: t.fireAt }
          }
        })
        // 标记已通知
        await db.collection('timers').doc(t._id).update({ data: { notified: true } })
      } catch (err) {
        console.error('send failed for timer', t._id, err)
        // errCode 43101 = 用户未订阅，标记 notified 避免重试
        if (err.errCode === 43101) {
          await db.collection('timers').doc(t._id).update({ data: { notified: true } })
        }
      }
    }

    // 3. 清理超过 25 小时的记录
    await db.collection('timers')
      .where({ createdAt: _.lt(expireBefore.toISOString()) })
      .remove()

    return { sent: due.length }
  } catch (err) {
    console.error('timer-notify error:', err)
    return { error: 'internal-error', message: String(err) }
  }
}