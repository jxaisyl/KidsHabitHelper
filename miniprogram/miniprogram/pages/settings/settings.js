var app = getApp()

Page({
  data: {
    version: '1.0.0',
    openid: ''
  },

  onLoad: function () {
    this.setData({ openid: app.globalData.openid || '' })
  },

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

  onFeedback: function () {
    wx.navigateToMiniProgram({
      appId: '',
      fail: function () {
        wx.showToast({ title: '暂未开放', icon: 'none' })
      }
    })
  },

  onAbout: function () {
    wx.showModal({
      title: '关于',
      content: '习惯养成助手 v1.0.0\n帮助家长管理孩子日常习惯，用积分奖励激励孩子成长。',
      showCancel: false
    })
  }
})
