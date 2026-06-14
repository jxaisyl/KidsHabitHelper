// 计时器纯逻辑工具：不依赖 wx API，便于人工验证

// 计算剩余秒数（向下取整，最小 0）
// 参数均为 ISO 字符串或 Date
function remainingSeconds(startAt, durationSec, now) {
  var start = typeof startAt === 'string' ? new Date(startAt).getTime() : startAt.getTime()
  var current = typeof now === 'string' ? new Date(now).getTime() : now.getTime()
  var elapsed = Math.floor((current - start) / 1000)
  var remain = durationSec - elapsed
  return remain < 0 ? 0 : remain
}

// 把秒格式化为 HH:MM:SS（24h 内）
function formatHMS(totalSec) {
  if (totalSec < 0) totalSec = 0
  var h = Math.floor(totalSec / 3600)
  var m = Math.floor((totalSec % 3600) / 60)
  var s = totalSec % 60
  return [h, m, s].map(function (n) {
    return n < 10 ? '0' + n : '' + n
  }).join(':')
}

// 校验时长：1..86400 秒
function isValidDuration(sec) {
  return typeof sec === 'number' && Number.isFinite(sec) && sec >= 1 && sec <= 86400
}

module.exports = {
  remainingSeconds: remainingSeconds,
  formatHMS: formatHMS,
  isValidDuration: isValidDuration
}