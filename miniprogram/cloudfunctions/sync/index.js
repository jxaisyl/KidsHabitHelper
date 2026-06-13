const cloud = require('wx-server-sdk')

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })
const db = cloud.database()
const _ = db.command

// Token 验证：从 Authorization header 解析 uid
function verifyToken(event) {
  const authHeader = (event.headers && event.headers.authorization) ||
                     (event.headers && event.headers.Authorization) || ''
  const token = authHeader.replace('Bearer ', '').trim()
  if (!token) return null
  // token 即为 users 集合中的 _id（注册/登录时返回）
  return token
}

exports.main = async (event, context) => {
  const method = event.httpMethod

  // --- Token 验证 ---
  const uid = verifyToken(event)
  if (!uid) {
    return { statusCode: 401, error: 'unauthorized', message: '未授权，请先登录' }
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
    // ===== GET /sync?collection=children&since=... =====
    if (method === 'GET') {
      // sync meta: GET /sync?collection=meta
      if (collection === 'meta') {
        const { data: meta } = await db.collection('sync_meta')
          .where({ userId: uid }).limit(1).get()
        if (meta.length === 0) {
          return { lastSyncTimestamp: null }
        }
        return { lastSyncTimestamp: meta[0].lastSyncTimestamp || null }
      }

      // 数据拉取
      if (!['children', 'rules', 'records'].includes(collection)) {
        return { statusCode: 400, error: 'invalid-collection', message: '无效的集合名称' }
      }

      let queryBuilder = db.collection(collection).where({ userId: uid })
      if (query.since) {
        queryBuilder = db.collection(collection).where({
          userId: uid,
          updatedAt: _.gt(new Date(query.since))
        })
      }

      const { data } = await queryBuilder.get()

      // 统一返回格式：将 _id 映射为 id
      return data.map(function (item) {
        item.id = item._id
        delete item._id
        return item
      })
    }

    // ===== POST /sync =====
    if (method === 'POST') {
      // sync meta update
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
        return { ok: true }
      }

      // 数据 upsert
      const coll = body.collection
      if (!['children', 'rules', 'records'].includes(coll)) {
        return { statusCode: 400, error: 'invalid-collection', message: '无效的集合名称' }
      }

      const itemData = body.data || {}
      const docId = itemData.id

      if (!docId) {
        return { statusCode: 400, error: 'missing-id', message: '缺少文档 ID' }
      }

      // 构建存储数据：添加 userId，移除 id 字段
      const storeData = { userId: uid }
      const fieldsToCopy = Object.assign({}, itemData)
      delete fieldsToCopy.id

      Object.assign(storeData, fieldsToCopy)
      storeData.updatedAt = new Date().toISOString()

      // 尝试 upsert：先查再更新或插入
      const { data: existing } = await db.collection(coll)
        .where({ _id: docId, userId: uid }).limit(1).get()

      if (existing.length > 0) {
        await db.collection(coll).doc(docId).update({ data: storeData })
      } else {
        storeData._id = docId
        await db.collection(coll).add({ data: storeData })
      }

      return { ok: true }
    }

    // ===== DELETE /sync?collection=children&id=xxx =====
    if (method === 'DELETE') {
      if (!['children', 'rules', 'records'].includes(collection)) {
        return { statusCode: 400, error: 'invalid-collection', message: '无效的集合名称' }
      }
      const docId = query.id
      if (!docId) {
        return { statusCode: 400, error: 'missing-id', message: '缺少文档 ID' }
      }

      // 验证文档属于该用户
      const { data: doc } = await db.collection(collection)
        .where({ _id: docId, userId: uid }).limit(1).get()

      if (doc.length === 0) {
        return { statusCode: 404, error: 'not-found', message: '文档不存在' }
      }

      await db.collection(collection).doc(docId).remove()
      return { ok: true }
    }

    return { statusCode: 405, error: 'method-not-allowed', message: '不支持的请求方法' }

  } catch (err) {
    console.error('sync error:', err)
    return { statusCode: 500, error: 'internal-error', message: '服务器错误' }
  }
}
