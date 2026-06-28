const util = require('../../utils/util.js')
const db = wx.cloud.database()
const app = getApp()

Page({
  data: {
    children: [],
    loading: true,
    today: '',
    isEmpty: false
  },

  onLoad: function () {
    this.setData({ today: util.formatDate(new Date()) })
  },

  onShow: function () {
    this.loadChildren()
  },

  onPullDownRefresh: function () {
    this.loadChildren().then(function () {
      wx.stopPullDownRefresh()
    })
  },

  loadChildren: function () {
    var that = this
    var openid = app.globalData.openid

    if (!openid) {
      // 等待 openid，最多重试 10 次（5秒）
      if (!that._retryCount) that._retryCount = 0
      that._retryCount++
      if (that._retryCount > 10) {
        that.setData({ loading: false, isEmpty: true })
        wx.showToast({ title: '请检查网络连接', icon: 'none' })
        return Promise.resolve()
      }
      setTimeout(function () { that.loadChildren() }, 500)
      return Promise.resolve()
    }

    // 已有数据时不显示加载状态，避免闪烁
    if (that.data.children.length === 0) {
      that.setData({ loading: true })
    }

    return db.collection('children')
      .where({ userId: openid })
      .orderBy('createdAt', 'asc')
      .get()
      .then(function (childrenRes) {
        var children = childrenRes.data

        return db.collection('records')
          .where({ userId: openid })
          .field({ childId: true, minutesChange: true })
          .get()
          .then(function (recordsRes) {
            var balanceMap = {}
            recordsRes.data.forEach(function (r) {
              if (!balanceMap[r.childId]) balanceMap[r.childId] = 0
              balanceMap[r.childId] += r.minutesChange || 0
            })

            children.forEach(function (c) {
              c.balance = balanceMap[c._id] || 0
            })

            // 首次启动且有孩子时，直接跳转到上次访问的孩子
            var isFirstLaunch = !app.globalData._indexLoaded
            app.globalData._indexLoaded = true

            if (isFirstLaunch && children.length > 0) {
              var lastId = wx.getStorageSync('lastChildId')
              var target = lastId && children.find(function (c) { return c._id === lastId })
              if (!target) target = children[0]
              wx.navigateTo({
                url: '/pages/detail/detail?childId=' + target._id
              })
            }

            that.setData({
              children: children,
              loading: false,
              isEmpty: children.length === 0
            })
          })
      })
      .catch(function (err) {
        console.error('加载孩子列表失败', err)
        that.setData({ loading: false })
        wx.showToast({ title: '加载失败', icon: 'none' })
      })
  },

  onChildTap: function (e) {
    var childId = e.currentTarget.dataset.id
    wx.navigateTo({
      url: '/pages/detail/detail?childId=' + childId
    })
  },

  onAddChild: function () {
    wx.navigateTo({
      url: '/pages/detail/detail?mode=add'
    })
  },

  onLongPressChild: function (e) {
    var that = this
    var childId = e.currentTarget.dataset.id
    var childName = e.currentTarget.dataset.name

    wx.showActionSheet({
      itemList: ['删除'],
      success: function (res) {
        if (res.tapIndex === 0) {
          wx.showModal({
            title: '确认删除',
            content: '确定要删除"' + childName + '"吗？所有相关记录将被清除。',
            confirmColor: '#F44336',
            success: function (modalRes) {
              if (modalRes.confirm) {
                that.deleteChild(childId)
              }
            }
          })
        }
      }
    })
  },

  deleteChild: function (childId) {
    var that = this
    var openid = app.globalData.openid

    db.collection('records')
      .where({ userId: openid, childId: childId })
      .get()
      .then(function (res) {
        var promises = res.data.map(function (r) {
          return db.collection('records').doc(r._id).remove()
        })
        return Promise.all(promises)
      })
      .then(function () {
        return db.collection('children').doc(childId).remove()
      })
      .then(function () {
        wx.showToast({ title: '已删除', icon: 'success' })
        that.loadChildren()
      })
      .catch(function (err) {
        console.error('删除失败', err)
        wx.showToast({ title: '删除失败', icon: 'none' })
      })
  }
})
