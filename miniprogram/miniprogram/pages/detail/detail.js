const util = require('../../utils/util.js')
const db = wx.cloud.database()
const app = getApp()

Page({
  data: {
    mode: 'view',
    childId: '',
    child: null,
    rules: [],
    todayRecords: [],
    today: '',
    todayTotal: 0,
    newChildName: '',
    newChildAvatar: '',
    submitting: false,
    loading: true
  },

  avatarOptions: ['👦', '👧', '👶', '🧒', '👦🏽', '👧🏽', '🧒🏻', '👶🏻'],

  onLoad: function (options) {
    var today = util.formatDate(new Date())
    this.setData({ today: today })

    if (options.mode === 'add') {
      this.setData({ mode: 'add', loading: false })
      wx.setNavigationBarTitle({ title: '添加孩子' })
    } else if (options.childId) {
      this.setData({ childId: options.childId })
      this.loadChildData()
    }
  },

  onShow: function () {
    if (this.data.childId && this.data.mode === 'view') {
      this.loadChildData()
    }
  },

  loadChildData: function () {
    var that = this
    var openid = app.globalData.openid
    that.setData({ loading: true })

    var childPromise = db.collection('children').doc(that.data.childId).get()
    var rulesPromise = db.collection('rules')
      .where({ userId: openid })
      .orderBy('minutesChange', 'desc')
      .get()

    var todayStart = that.data.today + 'T00:00:00.000Z'
    var todayEnd = that.data.today + 'T23:59:59.999Z'
    var recordsPromise = db.collection('records')
      .where({
        userId: openid,
        childId: that.data.childId,
        createdAt: db.command.gte(todayStart).and(db.command.lte(todayEnd))
      })
      .orderBy('createdAt', 'desc')
      .get()

    Promise.all([childPromise, rulesPromise, recordsPromise])
      .then(function (results) {
        var child = results[0].data
        var rules = results[1].data
        var todayRecords = results[2].data

        var todayTotal = 0
        var ruleMap = {}
        rules.forEach(function (r) { ruleMap[r._id] = r })
        todayRecords.forEach(function (r) {
          todayTotal += r.minutesChange || 0
          r.ruleName = r.ruleId && ruleMap[r.ruleId] ? ruleMap[r.ruleId].name : '自定义'
          r.ruleIcon = r.ruleId && ruleMap[r.ruleId] ? ruleMap[r.ruleId].icon : '📝'
        })

        that.setData({
          child: child,
          rules: rules,
          todayRecords: todayRecords,
          todayTotal: todayTotal,
          loading: false
        })
      })
      .catch(function (err) {
        console.error('加载详情失败', err)
        that.setData({ loading: false })
        wx.showToast({ title: '加载失败', icon: 'none' })
      })
  },

  onNameInput: function (e) {
    this.setData({ newChildName: e.detail.value })
  },

  onAvatarSelect: function (e) {
    this.setData({ newChildAvatar: e.currentTarget.dataset.avatar })
  },

  onSubmitAddChild: function () {
    var that = this
    var name = that.data.newChildName.trim()
    if (!name) {
      wx.showToast({ title: '请输入孩子姓名', icon: 'none' })
      return
    }

    var openid = app.globalData.openid
    that.setData({ submitting: true })

    db.collection('children').add({
      data: {
        userId: openid,
        name: name,
        avatar: that.data.newChildAvatar || '👦',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      }
    })
    .then(function () {
      wx.showToast({ title: '添加成功', icon: 'success' })
      setTimeout(function () { wx.navigateBack() }, 1000)
    })
    .catch(function (err) {
      console.error('添加失败', err)
      wx.showToast({ title: '添加失败', icon: 'none' })
      that.setData({ submitting: false })
    })
  },

  onRuleTap: function (e) {
    var that = this
    var ruleId = e.currentTarget.dataset.id
    var ruleName = e.currentTarget.dataset.name
    var ruleMinutes = e.currentTarget.dataset.minutes

    wx.showModal({
      title: '确认记录',
      content: '为"' + that.data.child.name + '"记录：' + ruleName + '（' + (ruleMinutes >= 0 ? '+' : '') + ruleMinutes + '分钟）',
      success: function (res) {
        if (res.confirm) {
          that.addRecord(ruleId, ruleMinutes)
        }
      }
    })
  },

  addRecord: function (ruleId, minutesChange) {
    var that = this
    var openid = app.globalData.openid

    db.collection('records').add({
      data: {
        userId: openid,
        childId: that.data.childId,
        ruleId: ruleId,
        minutesChange: minutesChange,
        note: '',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      }
    })
    .then(function () {
      wx.showToast({ title: '记录成功', icon: 'success' })
      that.loadChildData()
    })
    .catch(function (err) {
      console.error('记录失败', err)
      wx.showToast({ title: '记录失败', icon: 'none' })
    })
  },

  onDeleteRecord: function (e) {
    var that = this
    var recordId = e.currentTarget.dataset.id

    wx.showModal({
      title: '确认删除',
      content: '确定要删除这条记录吗？',
      confirmColor: '#F44336',
      success: function (res) {
        if (res.confirm) {
          db.collection('records').doc(recordId).remove()
            .then(function () {
              wx.showToast({ title: '已删除', icon: 'success' })
              that.loadChildData()
            })
            .catch(function (err) {
              console.error('删除失败', err)
              wx.showToast({ title: '删除失败', icon: 'none' })
            })
        }
      }
    })
  },

  onGoRuleManage: function () {
    wx.navigateTo({
      url: '/pages/rule-manage/rule-manage'
    })
  }
})
