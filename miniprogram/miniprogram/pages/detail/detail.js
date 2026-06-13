// pages/detail/detail.js
const util = require('../../utils/util.js')
const db = wx.cloud.database()

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
    newChildBirthDate: '',
    showRulePicker: false,
    pickerRules: [],
    pickerIndex: 0,
    loading: true,
    submitting: false
  },

  onLoad: function (options) {
    const today = util.formatDate(new Date())
    this.setData({ today: today })

    if (options.mode === 'add') {
      this.setData({ mode: 'add' })
      wx.setNavigationBarTitle({ title: '添加孩子' })
    } else if (options.childId) {
      this.setData({ childId: options.childId })
      this.loadChildData(options.childId)
    }
  },

  onShow: function () {
    if (this.data.childId) {
      this.loadChildData(this.data.childId)
    }
  },

  loadChildData: function (childId) {
    const that = this
    that.setData({ loading: true })

    wx.cloud.callFunction({
      name: 'sync',
      data: {
        action: 'getChildDetail',
        data: { childId: childId, date: that.data.today }
      }
    }).then(function (res) {
      const result = res.result
      const child = result.child || {}
      const rules = result.rules || []
      const todayRecords = result.todayRecords || []

      let todayTotal = 0
      todayRecords.forEach(function (r) {
        todayTotal += r.minutes || 0
      })

      that.setData({
        child: child,
        rules: rules,
        todayRecords: todayRecords,
        todayTotal: todayTotal,
        loading: false,
        pickerRules: rules
      })
    }).catch(function (err) {
      console.error('加载详情失败', err)
      that.setData({ loading: false })
      wx.showToast({ title: '加载失败', icon: 'none' })
    })
  },

  // 添加孩子
  onNameInput: function (e) {
    this.setData({ newChildName: e.detail.value })
  },

  onBirthDateChange: function (e) {
    this.setData({ newChildBirthDate: e.detail.value })
  },

  onSubmitAddChild: function () {
    var that = this
    var name = that.data.newChildName.trim()

    if (!name) {
      wx.showToast({ title: '请输入孩子姓名', icon: 'none' })
      return
    }

    that.setData({ submitting: true })

    wx.cloud.callFunction({
      name: 'sync',
      data: {
        action: 'addChild',
        data: {
          name: name,
          birthDate: that.data.newChildBirthDate || ''
        }
      }
    }).then(function (res) {
      wx.showToast({ title: '添加成功', icon: 'success' })
      setTimeout(function () {
        wx.navigateBack()
      }, 1000)
    }).catch(function (err) {
      console.error('添加失败', err)
      wx.showToast({ title: '添加失败', icon: 'none' })
      that.setData({ submitting: false })
    })
  },

  // 记录习惯
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
          that.addRecord(ruleId)
        }
      }
    })
  },

  addRecord: function (ruleId) {
    var that = this

    wx.cloud.callFunction({
      name: 'sync',
      data: {
        action: 'addRecord',
        data: {
          childId: that.data.childId,
          ruleId: ruleId,
          date: that.data.today,
          timestamp: Date.now()
        }
      }
    }).then(function (res) {
      wx.showToast({ title: '记录成功', icon: 'success' })
      that.loadChildData(that.data.childId)
    }).catch(function (err) {
      console.error('记录失败', err)
      wx.showToast({ title: '记录失败', icon: 'none' })
    })
  },

  // 删除记录
  onDeleteRecord: function (e) {
    var that = this
    var recordId = e.currentTarget.dataset.id

    wx.showModal({
      title: '确认删除',
      content: '确定要删除这条记录吗？',
      confirmColor: '#F44336',
      success: function (res) {
        if (res.confirm) {
          wx.cloud.callFunction({
            name: 'sync',
            data: {
              action: 'deleteRecord',
              data: { recordId: recordId }
            }
          }).then(function () {
            wx.showToast({ title: '已删除', icon: 'success' })
            that.loadChildData(that.data.childId)
          })
        }
      }
    })
  }
})
