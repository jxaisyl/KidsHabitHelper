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

    // 允许在静音模式下播放提示音（计时结束必须响）
    wx.setInnerAudioOption({ obeyMuteSwitch: false })

    this.getOpenId()
    this._startTimerWatch()
  },

  onShow: function () {
    // 切回前台时，如果计时已结束但提示音被后台拦截，重新播放
    this._replayTimerSoundIfNeeded()
  },

  _replayTimerSoundIfNeeded: function () {
    // 只有在「已触发 _onTimerFire 但用户还没确认/取消」时才重试
    if (!this._timerFiring) return
    var saved = wx.getStorageSync('activeTimer')
    if (!saved || saved.status !== 'ended') return
    // 销毁旧的（可能在后台时创建但未真正播放），重新创建一个
    if (this._audio) {
      try { this._audio.destroy() } catch (e) {}
      this._audio = null
    }
    this._audio = wx.createInnerAudioContext()
    this._audio.src = '/assets/audio/alert.mp3'
    this._audio.loop = true
    this._audio.onError(function (err) {
      console.error('音频播放失败', err)
    })
    this._audio.play()
  },

  // 全局倒计时检测：每秒检查 activeTimer 是否到期
  _startTimerWatch: function () {
    var that = this
    setInterval(function () {
      var saved = wx.getStorageSync('activeTimer')
      if (!saved || saved.status !== 'running') return
      if (that._timerFiring) return
      var fireTs = new Date(saved.fireAt).getTime()
      if (Date.now() >= fireTs) {
        that._timerFiring = true
        that._onTimerFire(saved)
      }
    }, 1000)
  },

  _onTimerFire: function (saved) {
    var that = this
    // 标记已结束，避免 detail 页 tick 重新激活
    saved.status = 'ended'
    wx.setStorageSync('activeTimer', saved)
    // 播放提示音：每次重新创建 audio 上下文，避免 stop 后 play 失效
    if (this._audio) {
      try { this._audio.destroy() } catch (e) {}
      this._audio = null
    }
    this._audio = wx.createInnerAudioContext()
    this._audio.src = '/assets/audio/alert.mp3'
    this._audio.loop = true
    this._audio.onError(function (err) {
      console.error('音频播放失败', err)
    })
    this._audio.play()

    var sign = saved.minutesChange >= 0 ? '+' : ''
    // 延迟弹窗，让提示音先响起来，避免 modal 打断音频
    setTimeout(function () {
      wx.showModal({
        title: '计时结束！',
        content: saved.ruleIcon + ' ' + saved.ruleName + '  ' + sign + saved.minutesChange + '分钟  → 给 ' + saved.childName,
        confirmText: '确认打卡',
        cancelText: '取消',
        success: function (res) {
          that._stopTimerSound()
          if (res.confirm) {
            that._confirmTimerRecord(saved)
          } else {
            that._clearActiveTimer(saved)
          }
        }
      })
    }, 500)
  },

  _stopTimerSound: function () {
    if (this._audio) {
      this._audio.stop()
    }
  },

  _confirmTimerRecord: function (saved) {
    var that = this
    var db = wx.cloud.database()
    db.collection('records').add({
      data: {
        userId: this.globalData.openid,
        childId: saved.childId,
        ruleId: saved.ruleId,
        minutesChange: saved.minutesChange,
        note: '计时器打卡',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      }
    }).then(function () {
      wx.showToast({ title: '记录成功', icon: 'success' })
    }).catch(function (err) {
      console.error('打卡失败', err)
      wx.showToast({ title: '打卡失败', icon: 'none' })
    })
    that._clearActiveTimer(saved)
  },

  _clearActiveTimer: function (saved) {
    saved = saved || wx.getStorageSync('activeTimer')
    if (saved && saved.ruleId) {
      var db = wx.cloud.database()
      db.collection('timers').where({
        userId: this.globalData.openid,
        ruleId: saved.ruleId,
        startAt: saved.startAt
      }).remove().catch(function () {})
    }
    wx.removeStorageSync('activeTimer')
    this._timerFiring = false
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
