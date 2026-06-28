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

            // 按日汇总
            var dailyMap = {}
            records.forEach(function (r) {
              var date = (r.createdAt || '').substring(0, 10)
              if (!dailyMap[date]) dailyMap[date] = 0
              dailyMap[date] += r.minutesChange || 0
            })
            var dailyData = []
            var cur = new Date(that.data.startDate + 'T00:00:00')
            var endDate = new Date(that.data.endDate + 'T00:00:00')
            while (cur <= endDate) {
              var ds = util.formatDate(cur)
              dailyData.push({ date: ds, total: dailyMap[ds] || 0 })
              cur.setDate(cur.getDate() + 1)
            }

            that.setData({
              records: records,
              dailyData: dailyData,
              summary: {
                totalMinutes: totalMinutes,
                positiveCount: positiveCount,
                negativeCount: negativeCount,
                dailyAvg: Math.round(totalMinutes / dayCount)
              },
              loading: false,
              isEmpty: records.length === 0
            }, function () {
              that.drawChart()
            })
          })
      })
      .catch(function (err) {
        console.error('加载统计数据失败', err)
        that.setData({ loading: false })
        wx.showToast({ title: '加载失败', icon: 'none' })
      })
  },

  drawChart: function () {
    var data = this.data.dailyData
    if (!data || data.length === 0) return

    var query = wx.createSelectorQuery()
    query.select('#trendChart').fields({ node: true, size: true }).exec(function (res) {
      if (!res[0]) return
      var canvas = res[0].node
      var ctx = canvas.getContext('2d')
      var dpr = wx.getSystemInfoSync().pixelRatio
      var w = res[0].width
      var h = res[0].height
      canvas.width = w * dpr
      canvas.height = h * dpr
      ctx.scale(dpr, dpr)

      // 边距
      var padL = 40, padR = 16, padT = 20, padB = 36
      var chartW = w - padL - padR
      var chartH = h - padT - padB

      // 找最大绝对值
      var maxAbs = 1
      data.forEach(function (d) {
        var a = Math.abs(d.total)
        if (a > maxAbs) maxAbs = a
      })

      // 背景网格
      ctx.strokeStyle = '#F0F0F0'
      ctx.lineWidth = 1
      for (var i = 0; i <= 4; i++) {
        var gy = padT + chartH * i / 4
        ctx.beginPath()
        ctx.moveTo(padL, gy)
        ctx.lineTo(w - padR, gy)
        ctx.stroke()
      }

      // 零线
      var zeroY = padT + chartH / 2
      ctx.strokeStyle = '#E0E0E0'
      ctx.lineWidth = 1
      ctx.setLineDash([4, 3])
      ctx.beginPath()
      ctx.moveTo(padL, zeroY)
      ctx.lineTo(w - padR, zeroY)
      ctx.stroke()
      ctx.setLineDash([])

      // Y轴标签
      ctx.fillStyle = '#999'
      ctx.font = '10px sans-serif'
      ctx.textAlign = 'right'
      ctx.fillText('+' + maxAbs, padL - 4, padT + 8)
      ctx.fillText('0', padL - 4, zeroY + 4)
      ctx.fillText('-' + maxAbs, padL - 4, padT + chartH - 2)

      // 计算点位
      var stepX = data.length > 1 ? chartW / (data.length - 1) : 0
      var points = data.map(function (d, i) {
        var x = padL + i * stepX
        var ratio = d.total / (maxAbs * 2) // -maxAbs~+maxAbs -> -0.5~0.5
        var y = zeroY - ratio * chartH
        return { x: x, y: y, val: d.total }
      })

      // 填充区域（零线以上的正值区域用浅绿，以下用浅红）
      // 先画正值部分
      ctx.fillStyle = 'rgba(76, 175, 80, 0.08)'
      ctx.beginPath()
      ctx.moveTo(points[0].x, zeroY)
      points.forEach(function (p) {
        ctx.lineTo(p.x, Math.min(p.y, zeroY))
      })
      ctx.lineTo(points[points.length - 1].x, zeroY)
      ctx.closePath()
      ctx.fill()

      // 画线
      ctx.strokeStyle = '#26A69A'
      ctx.lineWidth = 2
      ctx.lineJoin = 'round'
      ctx.beginPath()
      points.forEach(function (p, i) {
        if (i === 0) ctx.moveTo(p.x, p.y)
        else ctx.lineTo(p.x, p.y)
      })
      ctx.stroke()

      // 画点
      points.forEach(function (p) {
        ctx.beginPath()
        ctx.arc(p.x, p.y, 3, 0, 2 * Math.PI)
        ctx.fillStyle = p.val >= 0 ? '#4CAF50' : '#F44336'
        ctx.fill()
        ctx.strokeStyle = '#fff'
        ctx.lineWidth = 1.5
        ctx.stroke()
      })

      // X轴日期标签（稀疏显示）
      ctx.fillStyle = '#999'
      ctx.font = '9px sans-serif'
      ctx.textAlign = 'center'
      var labelStep = Math.ceil(data.length / 6)
      data.forEach(function (d, i) {
        if (i % labelStep === 0 || i === data.length - 1) {
          var label = d.date.substring(5) // MM-DD
          ctx.fillText(label, padL + i * stepX, h - padB + 14)
        }
      })
    })
  }
})
