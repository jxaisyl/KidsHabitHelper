// pages/statistics/statistics.js
const util = require('../../utils/util.js')

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

  onShow: function () {
    if (this.data.selectedChildId) {
      this.loadStatistics()
    }
  },

  loadChildren: function () {
    var that = this
    wx.cloud.callFunction({
      name: 'sync',
      data: { action: 'getChildren' }
    }).then(function (res) {
      var children = res.result.data || []
      that.setData({ children: children })

      if (children.length > 0) {
        that.setData({
          selectedChildId: children[0]._id,
          selectedChildName: children[0].name
        })
        that.loadStatistics()
      }
    }).catch(function (err) {
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
    if (!that.data.selectedChildId) return

    that.setData({ loading: true })

    wx.cloud.callFunction({
      name: 'sync',
      data: {
        action: 'getStatistics',
        data: {
          childId: that.data.selectedChildId,
          startDate: that.data.startDate,
          endDate: that.data.endDate
        }
      }
    }).then(function (res) {
      var result = res.result || {}
      var records = result.records || []
      var totalMinutes = 0
      var positiveCount = 0
      var negativeCount = 0

      records.forEach(function (r) {
        totalMinutes += r.minutes || 0
        if (r.minutes >= 0) {
          positiveCount++
        } else {
          negativeCount++
        }
      })

      var dayCount = Math.max(1, records.length > 0 ? 7 : 1)

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
    }).catch(function (err) {
      console.error('加载统计数据失败', err)
      that.setData({ loading: false })
      wx.showToast({ title: '加载失败', icon: 'none' })
    })
  }
})
