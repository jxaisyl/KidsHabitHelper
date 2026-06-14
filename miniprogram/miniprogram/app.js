App({
  onLaunch: function () {
    if (!wx.cloud) {
      console.error('请使用 2.2.3 或以上的基础库以使用云能力')
      return
    }

    wx.cloud.init({
      env: 'cloudbase-d7gdlreoq9bfaba40',
      traceUser: true
    })

    this.getOpenId()
  },

  onShow: function () {
    var saved = wx.getStorageSync('activeTimer')
    if (saved && saved.status === 'running') {
      var fireTs = new Date(saved.fireAt).getTime()
      if (Date.now() >= fireTs) {
        // 已到期：跳转到 timer 页让用户确认（timer.js onLoad 会处理）
        wx.navigateTo({
          url: '/pages/timer/timer?childId=' + saved.childId
        })
      }
    }
  },

  getOpenId: function () {
    var that = this
    wx.cloud.callFunction({
      name: 'login',
      data: {}
    }).then(function (res) {
      that.globalData.openid = res.result.openid
    }).catch(function (err) {
      console.error('获取 openid 失败', err)
    })
  },

  globalData: {
    openid: null
  }
})
