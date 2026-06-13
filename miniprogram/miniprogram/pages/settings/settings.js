var app = getApp()
var db = wx.cloud.database()

Page({
  data: {
    version: '1.0.0',
    openid: '',
    childCount: 0,
    ruleCount: 0,
    recordCount: 0,
    syncing: false
  },

  onLoad: function () {
    this.setData({ openid: app.globalData.openid || '' })
  },

  onShow: function () {
    this.loadStats()
  },

  loadStats: function () {
    var that = this
    var openid = app.globalData.openid
    if (!openid) return

    Promise.all([
      db.collection('children').where({ userId: openid }).count(),
      db.collection('rules').where({ userId: openid }).count(),
      db.collection('records').where({ userId: openid }).count()
    ]).then(function (results) {
      that.setData({
        childCount: results[0].total,
        ruleCount: results[1].total,
        recordCount: results[2].total
      })
    }).catch(function () {})
  },

  // 跳转到规则管理
  onGoRuleManage: function () {
    wx.navigateTo({
      url: '/pages/rule-manage/rule-manage'
    })
  },

  // 跳转到添加孩子
  onGoAddChild: function () {
    wx.navigateTo({
      url: '/pages/detail/detail?mode=add'
    })
  },

  // 清除缓存
  onClearCache: function () {
    wx.showModal({
      title: '清除缓存',
      content: '确定要清除本地缓存吗？云端数据不受影响。',
      success: function (res) {
        if (res.confirm) {
          wx.clearStorage({
            success: function () {
              wx.showToast({ title: '缓存已清除', icon: 'success' })
            }
          })
        }
      }
    })
  },

  // 意见反馈
  onFeedback: function () {
    // 使用微信内置反馈（需在 app.json 添加 plugin）
  },

  // 关于
  onAbout: function () {
    wx.showModal({
      title: '关于',
      content: '习惯养成助手 v1.0.0\n帮助家长管理孩子日常习惯，用积分奖励激励孩子成长。',
      showCancel: false
    })
  }
})
