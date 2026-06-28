var timerUtil = require('../../utils/timer.js')
var app = getApp()

// picker 的 range 必须是数组，不能用数字
var HOUR_RANGE = []
for (var i = 0; i < 24; i++) HOUR_RANGE.push(i)
var MINUTE_RANGE = []
for (var i = 0; i < 60; i++) MINUTE_RANGE.push(i)

Page({
  data: {
    childId: '',
    child: null,
    rules: [],
    selectedRuleId: '',
    selectedRule: null,
    hours: 0,
    minutes: 25,
    seconds: 0,
    hourRange: HOUR_RANGE,
    minuteRange: MINUTE_RANGE,
    secondRange: MINUTE_RANGE
  },

  onLoad: function (options) {
    // 读取上次设置的时长。模块顶层的代码只在 JS 首次加载时执行一次，
    // 后续 navigateTo 进入本页时不会重新执行，所以必须在 onLoad 里读取。
    var last = wx.getStorageSync('lastTimerSetting')
    if (last) {
      this.setData({
        hours: last.hours || 0,
        minutes: last.minutes !== undefined ? last.minutes : 25,
        seconds: last.seconds || 0
      })
    }
    if (options.childId) {
      this.setData({ childId: options.childId })
      this.loadChildAndRules(options.childId)
    }
  },

  onShow: function () {
    // 从 rule-manage 返回后刷新规则列表（首次 onShow 跳过，避免重复加载）
    if (this._loaded && this.data.childId) {
      this.loadChildAndRules(this.data.childId)
    }
  },

  loadChildAndRules: function (childId) {
    var that = this
    var openid = app.globalData.openid
    var db = wx.cloud.database()
    var childP = db.collection('children').doc(childId).get()
    var rulesP = db.collection('rules').where({ userId: openid }).orderBy('minutesChange', 'desc').get()
    Promise.all([childP, rulesP]).then(function (res) {
      that.setData({ child: res[0].data, rules: res[1].data })
      that._loaded = true
    }).catch(function (err) {
      console.error('加载失败', err)
      wx.showToast({ title: '加载失败', icon: 'none' })
    })
  },

  onHourChange: function (e) { this.setData({ hours: +e.detail.value }) },
  onMinuteChange: function (e) { this.setData({ minutes: +e.detail.value }) },
  onSecondChange: function (e) { this.setData({ seconds: +e.detail.value }) },
  onRuleSelect: function (e) {
    var id = e.currentTarget.dataset.id
    var rule = this.data.rules.filter(function (r) { return r._id === id })[0] || null
    this.setData({ selectedRuleId: id, selectedRule: rule })
  },

  onGoAddRule: function () {
    wx.navigateTo({ url: '/pages/rule-manage/rule-manage?action=add' })
  },

  onEditRule: function (e) {
    var ruleId = e.currentTarget.dataset.id
    wx.navigateTo({ url: '/pages/rule-manage/rule-manage?edit=' + ruleId })
  },

  onStart: function () {
    var that = this
    var totalSec = this.data.hours * 3600 + this.data.minutes * 60 + this.data.seconds
    if (!timerUtil.isValidDuration(totalSec)) {
      wx.showToast({ title: '请设置 1 秒 ~ 24 小时', icon: 'none' })
      return
    }
    if (!this.data.selectedRule) {
      wx.showToast({ title: '请选择规则', icon: 'none' })
      return
    }

    var startAt = new Date().toISOString()
    var fireAt = new Date(Date.now() + totalSec * 1000).toISOString()
    var saved = {
      childId: this.data.childId,
      childName: this.data.child.name,
      childAvatar: this.data.child.avatar,
      ruleId: this.data.selectedRule._id,
      ruleName: this.data.selectedRule.name,
      ruleIcon: this.data.selectedRule.icon,
      minutesChange: this.data.selectedRule.minutesChange,
      startAt: startAt,
      duration: totalSec,
      fireAt: fireAt,
      status: 'running'
    }
    wx.setStorageSync('activeTimer', saved)
    // 记住本次时间设置
    wx.setStorageSync('lastTimerSetting', {
      hours: this.data.hours,
      minutes: this.data.minutes,
      seconds: this.data.seconds
    })

    // 请求订阅消息授权，完成后返回详情页（由 app.js 全局检测到期）
    this._requestSubscribe(fireAt, saved)
  },

  _requestSubscribe: function (fireAt, saved) {
    var that = this
    var TEMPLATE_ID = '5nNhcgrDVmqgipdKeZqfHH92nzqYchJK5T6oLG99Z00'
    wx.requestSubscribeMessage({
      tmplIds: [TEMPLATE_ID],
      success: function (res) {
        if (res[TEMPLATE_ID] === 'accept') {
          var db = wx.cloud.database()
          db.collection('timers').add({
            data: {
              userId: app.globalData.openid,
              childId: saved.childId,
              childName: saved.childName,
              ruleId: saved.ruleId,
              ruleName: saved.ruleName,
              ruleIcon: saved.ruleIcon,
              minutesChange: saved.minutesChange,
              startAt: saved.startAt,
              duration: saved.duration,
              fireAt: fireAt,
              notified: false,
              createdAt: new Date().toISOString()
            }
          }).catch(function (e) { console.warn('写 timers 失败', e) })
        } else {
          console.warn('用户拒绝订阅消息授权')
        }
        wx.navigateBack()
      },
      fail: function (err) {
        console.warn('订阅授权失败', err)
        wx.navigateBack()
      }
    })
  }
})
