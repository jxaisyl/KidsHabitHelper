var db = wx.cloud.database()
var app = getApp()

Page({
  data: {
    rules: [],
    showForm: false,
    editingRuleId: '',
    formName: '',
    formSign: 1,
    formAbsMinutes: '30',
    formIcon: '',
    submitting: false,
    loading: true
  },

  iconOptions: ['✅', '📖', '🛁', '🌙', '🏃', '🧹', '🍎', '💪', '❌', '📱', '😢', '⏰'],

  onLoad: function (options) {
    this._pendingOptions = options
    this.loadRules()
  },

  onShow: function () {
    this.loadRules()
  },

  loadRules: function () {
    var that = this
    var openid = app.globalData.openid

    if (!openid) {
      setTimeout(function () { that.loadRules() }, 500)
      return
    }

    that.setData({ loading: true })
    db.collection('rules')
      .where({ userId: openid })
      .orderBy('minutesChange', 'desc')
      .get()
      .then(function (res) {
        that.setData({ rules: res.data, loading: false })
        // 处理来自 timer 页的跳转参数（仅首次）
        if (that._pendingOptions) {
          if (that._pendingOptions.action === 'add') {
            that.onShowAddForm()
          } else if (that._pendingOptions.edit) {
            var rule = res.data.filter(function (r) { return r._id === that._pendingOptions.edit })[0]
            if (rule) that.enterEditMode(rule)
          }
          that._pendingOptions = null
        }
      })
      .catch(function (err) {
        console.error('加载规则失败', err)
        that.setData({ loading: false })
      })
  },

  onShowAddForm: function () {
    this.setData({
      showForm: true,
      editingRuleId: '',
      formName: '',
      formSign: 1,
      formAbsMinutes: '30',
      formIcon: '✅'
    })
  },

  enterEditMode: function (rule) {
    this.setData({
      showForm: true,
      editingRuleId: rule._id,
      formName: rule.name,
      formSign: rule.minutesChange >= 0 ? 1 : -1,
      formAbsMinutes: String(Math.abs(rule.minutesChange)),
      formIcon: rule.icon || '✅'
    })
  },

  onEditRule: function (e) {
    this.enterEditMode(e.currentTarget.dataset.rule)
  },

  onCancelForm: function () {
    this.setData({ showForm: false })
  },

  onNameInput: function (e) {
    this.setData({ formName: e.detail.value })
  },

  onMinutesInput: function (e) {
    this.setData({ formAbsMinutes: e.detail.value })
  },

  onSelectSign: function (e) {
    this.setData({ formSign: Number(e.currentTarget.dataset.sign) })
  },

  onIconSelect: function (e) {
    this.setData({ formIcon: e.currentTarget.dataset.icon })
  },

  onSubmitForm: function () {
    var that = this
    var openid = app.globalData.openid
    var name = that.data.formName.trim()
    var absMinutes = parseInt(that.data.formAbsMinutes)
    var minutes = absMinutes * that.data.formSign

    if (!name) {
      wx.showToast({ title: '请输入规则名称', icon: 'none' })
      return
    }
    if (isNaN(absMinutes) || absMinutes === 0) {
      wx.showToast({ title: '请输入有效的分钟数', icon: 'none' })
      return
    }

    that.setData({ submitting: true })

    if (that.data.editingRuleId) {
      db.collection('rules').doc(that.data.editingRuleId).update({
        data: {
          name: name,
          minutesChange: minutes,
          icon: that.data.formIcon || '✅',
          updatedAt: new Date().toISOString()
        }
      })
      .then(function () {
        wx.showToast({ title: '更新成功', icon: 'success' })
        that.setData({ showForm: false, submitting: false })
        that.loadRules()
      })
      .catch(function (err) {
        console.error('更新失败', err)
        wx.showToast({ title: '更新失败', icon: 'none' })
        that.setData({ submitting: false })
      })
    } else {
      db.collection('rules').add({
        data: {
          userId: openid,
          name: name,
          minutesChange: minutes,
          icon: that.data.formIcon || '✅',
          updatedAt: new Date().toISOString()
        }
      })
      .then(function () {
        wx.showToast({ title: '添加成功', icon: 'success' })
        that.setData({ showForm: false, submitting: false })
        that.loadRules()
      })
      .catch(function (err) {
        console.error('添加失败', err)
        wx.showToast({ title: '添加失败', icon: 'none' })
        that.setData({ submitting: false })
      })
    }
  },

  onDeleteRule: function (e) {
    var that = this
    var ruleId = e.currentTarget.dataset.id
    var ruleName = e.currentTarget.dataset.name

    wx.showModal({
      title: '确认删除',
      content: '确定要删除规则"' + ruleName + '"吗？',
      confirmColor: '#F44336',
      success: function (res) {
        if (res.confirm) {
          db.collection('rules').doc(ruleId).remove()
            .then(function () {
              wx.showToast({ title: '已删除', icon: 'success' })
              that.loadRules()
            })
            .catch(function (err) {
              console.error('删除失败', err)
              wx.showToast({ title: '删除失败', icon: 'none' })
            })
        }
      }
    })
  }
})
