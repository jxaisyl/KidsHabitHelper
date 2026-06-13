const cloud = require('wx-server-sdk')

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })
const db = cloud.database()
const _ = db.command

exports.main = async (event, context) => {
  const uid = event.token
  if (!uid) {
    return { error: 'unauthorized', message: '未授权，请先登录' }
  }

  const action = event.action
  const collection = event.collection

  try {
    // ===== 拉取数据 =====
    if (action === 'pull') {
      if (collection === 'meta') {
        const { data: meta } = await db.collection('sync_meta')
          .where({ userId: uid }).limit(1).get()
        if (meta.length === 0) {
          return { lastSyncTimestamp: null }
        }
        return { lastSyncTimestamp: meta[0].lastSyncTimestamp || null }
      }

      if (!['children', 'rules', 'records'].includes(collection)) {
        return { error: 'invalid-collection', message: '无效的集合名称' }
      }

      let queryCond = { userId: uid }
      if (event.since) {
        queryCond = {
          userId: uid,
          updatedAt: _.gt(new Date(event.since))
        }
      }

      const { data } = await db.collection(collection).where(queryCond).get()

      const result = data.map(function (item) {
        item.id = item._id
        delete item._id
        return item
      })

      return result
    }

    // ===== 推送数据（upsert）=====
    if (action === 'push') {
      if (collection === 'meta') {
        const ts = event.lastSyncTimestamp
        const { data: existing } = await db.collection('sync_meta')
          .where({ userId: uid }).limit(1).get()

        if (existing.length > 0) {
          await db.collection('sync_meta').doc(existing[0]._id).update({
            data: { lastSyncTimestamp: ts || new Date().toISOString() }
          })
        } else {
          await db.collection('sync_meta').add({
            data: {
              userId: uid,
              lastSyncTimestamp: ts || new Date().toISOString()
            }
          })
        }
        return { ok: true }
      }

      if (!['children', 'rules', 'records'].includes(collection)) {
        return { error: 'invalid-collection', message: '无效的集合名称' }
      }

      const itemData = event.data || {}
      const docId = itemData.id

      if (!docId) {
        return { error: 'missing-id', message: '缺少文档 ID' }
      }

      const storeData = { userId: uid }
      const fieldsToCopy = Object.assign({}, itemData)
      delete fieldsToCopy.id

      Object.assign(storeData, fieldsToCopy)
      storeData.updatedAt = new Date().toISOString()

      const { data: existing } = await db.collection(coll || collection)
        .where({ _id: docId, userId: uid }).limit(1).get()

      if (existing.length > 0) {
        await db.collection(collection).doc(docId).update({ data: storeData })
      } else {
        storeData._id = docId
        await db.collection(collection).add({ data: storeData })
      }

      return { ok: true }
    }

    // ===== 删除数据 =====
    if (action === 'delete') {
      if (!['children', 'rules', 'records'].includes(collection)) {
        return { error: 'invalid-collection', message: '无效的集合名称' }
      }
      const docId = event.id
      if (!docId) {
        return { error: 'missing-id', message: '缺少文档 ID' }
      }

      const { data: doc } = await db.collection(collection)
        .where({ _id: docId, userId: uid }).limit(1).get()

      if (doc.length === 0) {
        return { error: 'not-found', message: '文档不存在' }
      }

      await db.collection(collection).doc(docId).remove()
      return { ok: true }
    }

    return { error: 'invalid-action', message: '未知操作: ' + action }

  } catch (err) {
    console.error('sync error:', err)
    return { error: 'internal-error', message: '服务器错误' }
  }
}
