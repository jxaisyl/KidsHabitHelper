const cloud = require('wx-server-sdk')

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })
const db = cloud.database()
const _ = db.command

function httpResponse(statusCode, data) {
  return {
    statusCode: statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }
}

// Token 验证：从 Authorization header 解析 uid
function verifyToken(event) {
  const authHeader = (event.headers && event.headers.authorization) ||
                     (event.headers && event.headers.Authorization) || ''
  const token = authHeader.replace('Bearer ', '').trim()
  if (!token) return null
  return token
}

exports.main = async (event, context) => {
  const method = event.httpMethod

  // --- Token 验证 ---
  const uid = verifyToken(event)
  if (!uid) {
    return httpResponse(401, { error: 'unauthorized', message: '未授权，请先登录' })
  }

  // 解析 query 参数
  const query = event.queryString || {}
  const collection = query.collection

  // 解析 body
  let body = {}
  if (event.body) {
    if (typeof event.body === 'string') {
      try { body = JSON.parse(event.body) } catch (e) { body = {} }
    } else {
      body = event.body
    }
  }

  try {
    // ===== GET =====
    if (method === 'GET') {
      if (collection === 'meta') {
        const { data: meta } = await db.collection('sync_meta')
          .where({ userId: uid }).limit(1).get()
        if (meta.length === 0) {
          return httpResponse(200, { lastSyncTimestamp: null })
        }
        return httpResponse(200, { lastSyncTimestamp: meta[0].lastSyncTimestamp || null })
      }

      if (!['children', 'rules', 'records'].includes(collection)) {
        return httpResponse(400, { error: 'invalid-collection', message: '无效的集合名称' })
      }

      let queryCond = { userId: uid }
      if (query.since) {
        queryCond = {
          userId: uid,
          updatedAt: _.gt(new Date(query.since))
        }
      }

      const { data } = await db.collection(collection).where(queryCond).get()

      const result = data.map(function (item) {
        item.id = item._id
        delete item._id
        return item
      })

      return httpResponse(200, result)
    }

    // ===== POST =====
    if (method === 'POST') {
      if (body.collection === 'meta' || collection === 'meta') {
        const ts = body.lastSyncTimestamp || (body.data && body.data.lastSyncTimestamp)
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
        return httpResponse(200, { ok: true })
      }

      const coll = body.collection
      if (!['children', 'rules', 'records'].includes(coll)) {
        return httpResponse(400, { error: 'invalid-collection', message: '无效的集合名称' })
      }

      const itemData = body.data || {}
      const docId = itemData.id

      if (!docId) {
        return httpResponse(400, { error: 'missing-id', message: '缺少文档 ID' })
      }

      const storeData = { userId: uid }
      const fieldsToCopy = Object.assign({}, itemData)
      delete fieldsToCopy.id

      Object.assign(storeData, fieldsToCopy)
      storeData.updatedAt = new Date().toISOString()

      const { data: existing } = await db.collection(coll)
        .where({ _id: docId, userId: uid }).limit(1).get()

      if (existing.length > 0) {
        await db.collection(coll).doc(docId).update({ data: storeData })
      } else {
        storeData._id = docId
        await db.collection(coll).add({ data: storeData })
      }

      return httpResponse(200, { ok: true })
    }

    // ===== DELETE =====
    if (method === 'DELETE') {
      if (!['children', 'rules', 'records'].includes(collection)) {
        return httpResponse(400, { error: 'invalid-collection', message: '无效的集合名称' })
      }
      const docId = query.id
      if (!docId) {
        return httpResponse(400, { error: 'missing-id', message: '缺少文档 ID' })
      }

      const { data: doc } = await db.collection(collection)
        .where({ _id: docId, userId: uid }).limit(1).get()

      if (doc.length === 0) {
        return httpResponse(404, { error: 'not-found', message: '文档不存在' })
      }

      await db.collection(collection).doc(docId).remove()
      return httpResponse(200, { ok: true })
    }

    return httpResponse(405, { error: 'method-not-allowed', message: '不支持的请求方法' })

  } catch (err) {
    console.error('sync error:', err)
    return httpResponse(500, { error: 'internal-error', message: '服务器错误' })
  }
}
