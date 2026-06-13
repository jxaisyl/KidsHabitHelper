// 云函数 - sync
// 处理 children、rules、records 三个集合的 CRUD 操作
const cloud = require('wx-server-sdk')

cloud.init({
  env: cloud.DYNAMIC_CURRENT_ENV
})

const db = cloud.database()
const _ = db.command

exports.main = async (event, context) => {
  const wxContext = cloud.getWXContext()
  const openid = wxContext.OPENID
  const { action, data } = event

  try {
    switch (action) {

      // ========== 孩子 (Children) ==========

      case 'getChildren': {
        const result = await db.collection('children')
          .where({ _openid: openid })
          .orderBy('createdAt', 'asc')
          .get()
        return { code: 200, data: result.data }
      }

      case 'getChildDetail': {
        const { childId, date } = data

        // 获取孩子信息
        const childRes = await db.collection('children')
          .doc(childId)
          .get()
        const child = childRes.data

        // 获取所有规则
        const rulesRes = await db.collection('rules')
          .where({ _openid: openid })
          .orderBy('minutes', 'desc')
          .get()
        const rules = rulesRes.data

        // 获取今日记录
        const todayStart = new Date(date + ' 00:00:00')
        const todayEnd = new Date(date + ' 23:59:59')
        const recordsRes = await db.collection('records')
          .where({
            _openid: openid,
            childId: childId,
            date: date
          })
          .orderBy('timestamp', 'desc')
          .get()
        const todayRecords = recordsRes.data

        // 补充规则名称到记录中
        const ruleMap = {}
        rules.forEach(function (r) { ruleMap[r._id] = r })
        todayRecords.forEach(function (r) {
          if (r.ruleId && ruleMap[r.ruleId]) {
            r.ruleName = ruleMap[r.ruleId].name
          }
        })

        return {
          code: 200,
          child: child,
          rules: rules,
          todayRecords: todayRecords
        }
      }

      case 'addChild': {
        const { name, birthDate } = data
        const result = await db.collection('children').add({
          data: {
            _openid: openid,
            name: name,
            birthDate: birthDate || '',
            balance: 0,
            createdAt: db.serverDate(),
            updatedAt: db.serverDate()
          }
        })
        return { code: 200, data: { _id: result._id }, message: '添加成功' }
      }

      case 'updateChild': {
        const { childId, name, birthDate } = data
        const updateData = { updatedAt: db.serverDate() }
        if (name !== undefined) updateData.name = name
        if (birthDate !== undefined) updateData.birthDate = birthDate

        await db.collection('children').doc(childId).update({ data: updateData })
        return { code: 200, message: '更新成功' }
      }

      case 'deleteChild': {
        const { childId } = data

        // 删除孩子关联的所有记录
        const records = await db.collection('records')
          .where({ _openid: openid, childId: childId })
          .get()
        const deletePromises = records.data.map(function (r) {
          return db.collection('records').doc(r._id).remove()
        })
        await Promise.all(deletePromises)

        // 删除孩子
        await db.collection('children').doc(childId).remove()

        return { code: 200, message: '删除成功' }
      }

      // ========== 规则 (Rules) ==========

      case 'getRules': {
        const result = await db.collection('rules')
          .where({ _openid: openid })
          .orderBy('minutes', 'desc')
          .get()
        return { code: 200, data: result.data }
      }

      case 'addRule': {
        const { name, minutes, icon, description } = data
        const result = await db.collection('rules').add({
          data: {
            _openid: openid,
            name: name,
            minutes: minutes,
            icon: icon || '',
            description: description || '',
            createdAt: db.serverDate(),
            updatedAt: db.serverDate()
          }
        })
        return { code: 200, data: { _id: result._id }, message: '添加成功' }
      }

      case 'updateRule': {
        const { ruleId, name, minutes, icon, description } = data
        const updateData = { updatedAt: db.serverDate() }
        if (name !== undefined) updateData.name = name
        if (minutes !== undefined) updateData.minutes = minutes
        if (icon !== undefined) updateData.icon = icon
        if (description !== undefined) updateData.description = description

        await db.collection('rules').doc(ruleId).update({ data: updateData })
        return { code: 200, message: '更新成功' }
      }

      case 'deleteRule': {
        const { ruleId } = data
        await db.collection('rules').doc(ruleId).remove()
        return { code: 200, message: '删除成功' }
      }

      // ========== 记录 (Records) ==========

      case 'addRecord': {
        const { childId, ruleId, date, timestamp } = data

        // 获取规则详情
        const ruleRes = await db.collection('rules').doc(ruleId).get()
        const rule = ruleRes.data
        const minutes = rule.minutes

        // 创建记录
        const result = await db.collection('records').add({
          data: {
            _openid: openid,
            childId: childId,
            ruleId: ruleId,
            ruleName: rule.name,
            minutes: minutes,
            date: date,
            timestamp: timestamp || Date.now(),
            createdAt: db.serverDate()
          }
        })

        // 更新孩子余额
        await db.collection('children').doc(childId).update({
          data: {
            balance: _.inc(minutes),
            updatedAt: db.serverDate()
          }
        })

        return { code: 200, data: { _id: result._id, minutes: minutes }, message: '记录成功' }
      }

      case 'deleteRecord': {
        const { recordId } = data

        // 获取记录详情以回滚余额
        const recordRes = await db.collection('records').doc(recordId).get()
        const record = recordRes.data

        // 删除记录
        await db.collection('records').doc(recordId).remove()

        // 回滚余额
        await db.collection('children').doc(record.childId).update({
          data: {
            balance: _.inc(-record.minutes),
            updatedAt: db.serverDate()
          }
        })

        return { code: 200, message: '删除成功' }
      }

      // ========== 统计 ==========

      case 'getStatistics': {
        const { childId, startDate, endDate } = data

        const recordsRes = await db.collection('records')
          .where({
            _openid: openid,
            childId: childId,
            date: _.gte(startDate).and(_.lte(endDate))
          })
          .orderBy('date', 'desc')
          .get()

        return { code: 200, records: recordsRes.data }
      }

      default:
        return { code: 400, message: '未知操作: ' + action }
    }
  } catch (err) {
    console.error('sync 云函数错误:', err)
    return { code: 500, message: '服务器错误: ' + err.message }
  }
}
