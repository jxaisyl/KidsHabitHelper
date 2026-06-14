var timerUtil = require('../../utils/timer.js')
var app = getApp()

Page({
  data: {
    mode: 'setup',              // setup | running | ended
    childId: '',
    child: null,
    rules: [],
    selectedRuleId: '',         // 选中的规则 _id
    selectedRule: null,
    // setup 字段
    hours: 0,
    minutes: 25,
    seconds: 0,
    // running 字段
    display: '00:25:00',
    progress: 0,                // 0..1
    startAt: '',
    duration: 0,
    fireAt: ''
  },

  _tickHandle: null,
  _audio: null,

  onLoad: function (options) {
    var that = this
    if (options.childId) {
      this.setData({ childId: options.childId })
      this.loadChildAndRules(options.childId)
    }

    // 异常恢复：检查是否有进行中的计时器
    var saved = wx.getStorageSync('activeTimer')
    if (saved && saved.status === 'running' && saved.childId === options.childId) {
      var now = Date.now()
      var fireTs = new Date(saved.fireAt).getTime()
      if (now >= fireTs) {
        // 已到期：直接进入结束态
        this._restoreFromSaved(saved, true)
        this._onTimerEnd()
      } else {
        // 未到期：恢复运行态
        this._restoreFromSaved(saved, false)
        this._startTicking()
      }
    }
  },

  onUnload: function () {
    this._stopTicking()
    wx.setKeepScreenOn({ keepScreenOn: false })
  },

  loadChildAndRules: function (childId) {
    var that = this
    var openid = app.globalData.openid
    var db = wx.cloud.database()
    var childP = db.collection('children').doc(childId).get()
    var rulesP = db.collection('rules').where({ userId: openid }).orderBy('minutesChange', 'desc').get()
    Promise.all([childP, rulesP]).then(function (res) {
      that.setData({ child: res[0].data, rules: res[1].data })
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
    this._restoreFromSaved(saved, false)

    // 屏幕常亮
    wx.setKeepScreenOn({ keepScreenOn: true })

    // 请求订阅消息授权（失败不阻塞前台计时）
    this._requestSubscribe(fireAt, saved)

    this._startTicking()
  },

  _requestSubscribe: function (fireAt, saved) {
    var that = this
    // TEMPLATE_ID 部署前替换为小程序后台申请的订阅消息模板 ID
    var TEMPLATE_ID = 'REPLACE_WITH_TEMPLATE_ID'
    wx.requestSubscribeMessage({
      tmplIds: [TEMPLATE_ID],
      success: function (res) {
        if (res[TEMPLATE_ID] === 'accept') {
          // 写入 timers 云集合，供定时触发器扫描
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
        }
      },
      fail: function () { /* 用户拒绝不影响前台计时 */ }
    })
  },

  _restoreFromSaved: function (saved, ended) {
    this.setData({
      mode: ended ? 'ended' : 'running',
      selectedRuleId: saved.ruleId,
      selectedRule: {
        _id: saved.ruleId, name: saved.ruleName, icon: saved.ruleIcon, minutesChange: saved.minutesChange
      },
      startAt: saved.startAt,
      duration: saved.duration,
      fireAt: saved.fireAt,
      display: timerUtil.formatHMS(saved.duration),
      progress: 0
    })
  },

  _startTicking: function () {
    var that = this
    this._stopTicking()
    var tick = function () {
      var remain = timerUtil.remainingSeconds(that.data.startAt, that.data.duration, new Date())
      that.setData({
        display: timerUtil.formatHMS(remain),
        progress: 1 - (remain / that.data.duration)
      })
      if (remain <= 0) {
        that._stopTicking()
        that._onTimerEnd()
      }
    }
    tick()
    this._tickHandle = setInterval(tick, 1000)
  },

  _stopTicking: function () {
    if (this._tickHandle) {
      clearInterval(this._tickHandle)
      this._tickHandle = null
    }
  },

  _onTimerEnd: function () {
    var that = this
    this.setData({ mode: 'ended' })
    // 播放提示音
    if (!this._audio) {
      this._audio = wx.createInnerAudioContext()
      this._audio.src = '/assets/audio/alert.mp3'
      this._audio.loop = true
    }
    this._audio.play()
    wx.setKeepScreenOn({ keepScreenOn: false })
    // 弹确认框
    var rule = this.data.selectedRule
    var sign = rule.minutesChange >= 0 ? '+' : ''
    wx.showModal({
      title: '计时结束！',
      content: rule.icon + ' ' + rule.name + '  ' + sign + rule.minutesChange + '分钟  → 给 ' + (this.data.child ? this.data.child.name : ''),
      confirmText: '确认打卡',
      cancelText: '取消',
      success: function (res) {
        that._stopSound()
        if (res.confirm) {
          that._confirmRecord()
        } else {
          that._clearTimer()
        }
      }
    })
  },

  _stopSound: function () {
    if (this._audio) {
      this._audio.stop()
    }
  },

  _confirmRecord: function () {
    var that = this
    var openid = app.globalData.openid
    var rule = this.data.selectedRule
    var db = wx.cloud.database()
    db.collection('records').add({
      data: {
        userId: openid,
        childId: that.data.childId,
        ruleId: rule._id,
        minutesChange: rule.minutesChange,
        note: '计时器打卡',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      }
    }).then(function () {
      wx.showToast({ title: '记录成功', icon: 'success' })
      that._clearTimer()
    }).catch(function (err) {
      console.error('打卡失败', err)
      wx.showToast({ title: '打卡失败', icon: 'none' })
    })
  },

  _clearTimer: function () {
    var saved = wx.getStorageSync('activeTimer')
    if (saved && saved.ruleId) {
      // 清理 timers 云集合中对应文档（best-effort）
      var db = wx.cloud.database()
      db.collection('timers').where({
        userId: app.globalData.openid,
        ruleId: saved.ruleId,
        startAt: saved.startAt
      }).remove().catch(function () {})
    }
    wx.removeStorageSync('activeTimer')
    this.setData({
      mode: 'setup', selectedRuleId: '', selectedRule: null,
      display: '00:00:00', progress: 0, startAt: '', duration: 0, fireAt: ''
    })
    setTimeout(function () { wx.navigateBack() }, 500)
  },

  onCancel: function () {
    var that = this
    wx.showModal({
      title: '取消计时',
      content: '确定取消当前计时？',
      success: function (res) {
        if (res.confirm) {
          that._stopTicking()
          that._stopSound()
          wx.setKeepScreenOn({ keepScreenOn: false })
          that._clearTimer()
        }
      }
    })
  }
})
