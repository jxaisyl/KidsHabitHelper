// app.js
App({
  onLaunch: function () {
    if (!wx.cloud) {
      console.error('请使用 2.2.3 或以上的基础库以使用云能力')
    } else {
      wx.cloud.init({
        traceUser: true
      })
    }

    this.globalData = {}

    // 获取用户 openid
    this.getOpenId()
  },

  getOpenId: function () {
    if (wx.cloud) {
      wx.cloud.callFunction({
        name: 'login',
        data: {}
      }).then(res => {
        this.globalData.openid = res.result.openid
        this.globalData.userInfo = res.result.userInfo || null
      }).catch(err => {
        console.error('获取 openid 失败', err)
      })
    }
  },

  globalData: {
    openid: null,
    userInfo: null,
    currentChild: null
  }
})
