const util = require('../../utils/util.js')
const db = wx.cloud.database()
const _ = db.command
const app = getApp()

Page({
  data: {
    children: [],
    selectedChildId: '',
    selectedChildName: '',
    dateRange: 'week',
    startDate: '',
    endDate: '',
    records: [],
    summary: {
      totalMinutes: 0,
      positiveCount: 0,
      negativeCount: 0,
      dailyAvg: 0
    },
    loading: false,
    isEmpty: true
  },

  onLoad: function () {
    var end = new Date()
    var start = new Date()
    start.setDate(start.getDate() - 7)
    this.setData({
      endDate: util.formatDate(end),
      startDate: util.formatDate(start)
    })
    this.loadChildren()
  },

  loadChildren: function () {
    var that = this
    var openid = app.globalData.openid

    if (!openid) {
      setTimeout(function () { that.loadChildren() }, 500)
      return
    }

    db.collection('children')
      .where({ userId: openid })
      .orderBy('createdAt', 'asc')
      .get()
      .then(function (res) {
        var children = res.data || []
        that.setData({ children: children })
        if (children.length > 0) {
          that.setData({
            selectedChildId: children[0]._id,
            selectedChildName: children[0].name
          })
          that.loadStatistics()
        }
      })
      .catch(function (err) {
        console.error('加载孩子列表失败', err)
      })
  },

  onChildChange: function (e) {
    var index = e.detail.value
    var child = this.data.children[index]
    this.setData({
      selectedChildId: child._id,
      selectedChildName: child.name
    })
    this.loadStatistics()
  },

  onDateRangeChange: function (e) {
    var range = e.currentTarget.dataset.range
    var end = new Date()
    var start = new Date()

    if (range === 'week') {
      start.setDate(start.getDate() - 7)
    } else if (range === 'month') {
      start.setMonth(start.getMonth() - 1)
    } else if (range === 'quarter') {
      start.setMonth(start.getMonth() - 3)
    }

    this.setData({
      dateRange: range,
      startDate: util.formatDate(start),
      endDate: util.formatDate(end)
    })
    this.loadStatistics()
  },

  loadStatistics: function () {
    var that = this
    var openid = app.globalData.openid
    if (!that.data.selectedChildId || !openid) return

    that.setData({ loading: true })

    var startISO = that.data.startDate + 'T00:00:00.000Z'
    var endISO = that.data.endDate + 'T23:59:59.999Z'

    db.collection('records')
      .where({
        userId: openid,
        childId: that.data.selectedChildId,
        createdAt: _.gte(startISO).and(_.lte(endISO))
      })
      .orderBy('createdAt', 'desc')
      .get()
      .then(function (res) {
        var records = res.data
        var totalMinutes = 0
        var positiveCount = 0
        var negativeCount = 0

        records.forEach(function (r) {
          totalMinutes += r.minutesChange || 0
          if (r.minutesChange >= 0) positiveCount++
          else negativeCount++
        })

        return db.collection('rules')
          .where({ userId: openid })
          .get()
          .then(function (rulesRes) {
            var ruleMap = {}
            rulesRes.data.forEach(function (r) { ruleMap[r._id] = r })
            records.forEach(function (r) {
              r.ruleName = r.ruleId && ruleMap[r.ruleId] ? ruleMap[r.ruleId].name : '自定义'
            })

            var dayCount = that.data.dateRange === 'week' ? 7 :
                           that.data.dateRange === 'month' ? 30 : 90

            that.setData({
              records: records,
              summary: {
                totalMinutes: totalMinutes,
                positiveCount: positiveCount,
                negativeCount: negativeCount,
                dailyAvg: Math.round(totalMinutes / dayCount)
              },
              loading: false,
              isEmpty: records.length === 0
            })
          })
      })
      .catch(function (err) {
        console.error('加载统计数据失败', err)
        that.setData({ loading: false })
        wx.showToast({ title: '加载失败', icon: 'none' })
      })
  }
})
