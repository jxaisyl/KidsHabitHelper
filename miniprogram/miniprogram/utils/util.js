// utils/util.js - 日期格式化与通用工具函数

/**
 * 格式化日期为 YYYY-MM-DD
 * @param {Date} date
 * @returns {string}
 */
function formatDate(date) {
  var year = date.getFullYear()
  var month = date.getMonth() + 1
  var day = date.getDate()

  return [year, month, day].map(formatNumber).join('-')
}

/**
 * 格式化日期为中文格式 YYYY年MM月DD日
 * @param {Date} date
 * @returns {string}
 */
function formatDateCN(date) {
  var year = date.getFullYear()
  var month = date.getMonth() + 1
  var day = date.getDate()

  return year + '年' + month + '月' + day + '日'
}

/**
 * 格式化时间为 HH:mm
 * @param {Date} date
 * @returns {string}
 */
function formatTime(date) {
  var hour = date.getHours()
  var minute = date.getMinutes()

  return [hour, minute].map(formatNumber).join(':')
}

/**
 * 格式化日期时间为 YYYY-MM-DD HH:mm:ss
 * @param {Date} date
 * @returns {string}
 */
function formatDateTime(date) {
  return formatDate(date) + ' ' + formatTime(date)
}

/**
 * 补零
 * @param {number} n
 * @returns {string}
 */
function formatNumber(n) {
  n = n.toString()
  return n[1] ? n : '0' + n
}

/**
 * 获取两个日期之间的所有日期
 * @param {string} startDateStr - YYYY-MM-DD
 * @param {string} endDateStr - YYYY-MM-DD
 * @returns {string[]}
 */
function getDateRange(startDateStr, endDateStr) {
  var dates = []
  var start = new Date(startDateStr)
  var end = new Date(endDateStr)

  while (start <= end) {
    dates.push(formatDate(start))
    start.setDate(start.getDate() + 1)
  }

  return dates
}

/**
 * 获取星期几的中文表示
 * @param {Date} date
 * @returns {string}
 */
function getWeekDay(date) {
  var weekDays = ['日', '一', '二', '三', '四', '五', '六']
  return '星期' + weekDays[date.getDay()]
}

/**
 * 计算两个日期之间的天数差
 * @param {string} dateStr1
 * @param {string} dateStr2
 * @returns {number}
 */
function daysBetween(dateStr1, dateStr2) {
  var d1 = new Date(dateStr1)
  var d2 = new Date(dateStr2)
  var diff = Math.abs(d2 - d1)
  return Math.floor(diff / (24 * 60 * 60 * 1000))
}

module.exports = {
  formatDate: formatDate,
  formatDateCN: formatDateCN,
  formatTime: formatTime,
  formatDateTime: formatDateTime,
  formatNumber: formatNumber,
  getDateRange: getDateRange,
  getWeekDay: getWeekDay,
  daysBetween: daysBetween
}
