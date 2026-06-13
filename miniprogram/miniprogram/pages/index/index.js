// pages/index/index.js
const util = require('../../utils/util.js')

Page({
  data: {
    children: [],
    loading: true,
    today: '',
    isEmpty: false
  },

  onLoad: function () {
    this.setData({
      today: util.formatDate(new Date())
    })
  },

  onShow: function () {
    this.loadChildren()
  },

  onPullDownRefresh: function () {
    this.loadChildren().then(() => {
      wx.stopPullDownRefresh()
    })
  },

  loadChildren: function () {
    const that = this
    that.setData({ loading: true })

    return wx.cloud.callFunction({
      name: 'sync',
      data: {
        action: 'getChildren'
      }
    }).then(res => {
      const children = res.result.data || []
      that.setData({
        children: children,
        loading: false,
        isEmpty: children.length === 0
      })
    }).catch(err => {
      console.error('加载孩子列表失败', err)
      that.setData({ loading: false })
      wx.showToast({
        title: '加载失败',
        icon: 'none'
      })
    })
  },

  onChildTap: function (e) {
    const childId = e.currentTarget.dataset.id
    wx.navigateTo({
      url: '/pages/detail/detail?childId=' + childId
    })
  },

  onAddChild: function () {
    wx.navigateTo({
      url: '/pages/detail/detail?mode=add'
    })
  },

  onLongPressChild: function (e) {
    const childId = e.currentTarget.dataset.id
    const childName = e.currentTarget.dataset.name
    wx.showActionSheet({
      itemList: ['删除'],
      success: function (res) {
        if (res.tapIndex === 0) {
          wx.showModal({
            title: '确认删除',
            content: '确定要删除"' + childName + '"吗？所有相关记录将被清除。',
            confirmColor: '#F44336',
            success: function (modalRes) {
              if (modalRes.confirm) {
                wx.cloud.callFunction({
                  name: 'sync',
                  data: {
                    action: 'deleteChild',
                    data: { childId: childId }
                  }
                }).then(function () {
                  wx.showToast({ title: '已删除', icon: 'success' })
                  that.loadChildren()
                })
              }
            }
          })
        }
      }
    })
    var that = this
  }
})
