RULER_BACKGROUND = '#2e2e2e'
TIME_BACKGROUND = 'black'
FONT_SIZE = 15
FONT_FAMILY = 'sans-serif'
ALIGN_LEFT = 1
ALIGN_RIGHT = -1
PADDING = 20
CURSOR_COLOR = 'yellow'
CURSOR_WIDTH = 3
GRID_COLOR = '#888888'
GRID_WIDTH = 1
MARKER_FG = 'white'
MARKER_BG = 'red'
MARKER_WIDTH = 2
TYPE_CURSOR = 1
TYPE_GRID = 2
TYPE_MARKER = 3
SNAP_THRESHOLD = 50
SEEK_COLOR = 'orange'
SEEK_DELAY = 500 # in milliseconds

EventEmitter = require('events').EventEmitter

class Timeline extends EventEmitter
  constructor: (@_canvas) ->
    @_snapPoints = []
    @_rulerTop = FONT_SIZE

    @_ctx = @_canvas.getContext '2d'

    @_hasTouch = 'ontouchstart' of window
    mousedown = if @_hasTouch then 'touchstart' else 'mousedown'
    mousemove = if @_hasTouch then 'touchmove' else 'mousemove'
    mouseup = if @_hasTouch then 'touchend' else 'mouseup'
    click = if @_hasTouch then 'touchend' else 'click'

    @_canvas.addEventListener mousedown, =>
      [@_mouseTime, @_disableSnap] = [new Date(), false]

    window.addEventListener mouseup, =>
      @_mouseTime = null
      if @_seekPreview
        @_seekPreview = null
        @update @_data

    window.addEventListener mousemove, (e) =>
      [x, y] = @_mousePos e
      if @_mouseTime && @_mouseTime < (new Date()) - SEEK_DELAY
        pos = Math.max 1, Math.min(x, @_canvas.width)
        @_disableSnap = true
        @_seekPreview = @_pxToTime pos
        @update @_data

      if @_isMouseOver x, y
        # prevent scrolling on mobile when zoomed
        e.preventDefault()
        false

    @_canvas.addEventListener click, (e) =>
      [x, y] = @_mousePos e
      return unless @_isMouseOver x, y
      x = @_snap x unless @_disableSnap
      @emit 'seek', @_pxToTime(x) + @_data.state.startTime

  update: (@_data) ->
    @_snapPoints.length = 0
    @_resize()

    @_ctx.textBaseline = 'hanging'

    @_ctx.fillStyle = RULER_BACKGROUND
    @_ctx.fillRect 0, @_rulerTop, @_canvas.width, @_rulerHeight

    @_gridLine 0
    @_gridLine @_data.state.endTime - @_data.state.startTime

    [@_ctx.strokeStyle, @_ctx.fillStyle] = [MARKER_BG, MARKER_BG]
    for marker in @_data.markerList when marker.time >= @_data.state.startTime and marker.time <= @_data.state.endTime
      @_marker marker

    @_editCursor @_data.position - @_data.state.startTime

    if @_data.position < @_data.state.startTime
      @_outOfBounds ALIGN_LEFT
    else if @_data.position > @_data.state.endTime
      @_outOfBounds ALIGN_RIGHT

    @_ctx.strokeStyle = @_ctx.fillStyle = SEEK_COLOR
    @_rulerTick @_seekPreview if @_seekPreview

    @_snapPoints.sort (a, b) -> a - b

  _resize: ->
    [@_canvas.width, @_canvas.height] = [@_canvas.clientWidth, @_canvas.clientHeight]

    @_rulerHeight = @_canvas.height - (@_rulerTop * 2)
    @_rulerBottom = @_rulerTop + @_rulerHeight

    @_scale = (@_data.state.endTime - @_data.state.startTime) / @_canvas.width
    @_scale ||= 1 / Math.pow(2,32)

  _editCursor: (time) ->
    pos = @_timeToPx time

    @_ctx.strokeStyle = @_ctx.fillStyle = CURSOR_COLOR
    @_ctx.lineWidth = CURSOR_WIDTH

    @_ctx.beginPath()
    @_ctx.moveTo pos - @_rulerTop, 0
    @_ctx.lineTo pos, @_rulerTop + CURSOR_WIDTH
    @_ctx.lineTo pos + @_rulerTop, 0
    @_ctx.fill()

    @_rulerTick time, false

  _gridLine: (time) ->
    @_ctx.strokeStyle = @_ctx.fillStyle = GRID_COLOR
    @_ctx.lineWidth = GRID_WIDTH
    @_rulerTick time

  _marker: (marker) ->
    time = marker.time - @_data.state.startTime
    pos = @_timeToPx time

    blankerPos = pos - (MARKER_WIDTH * 2)
    @_ctx.fillStyle = RULER_BACKGROUND
    @_ctx.fillRect blankerPos, @_rulerTop, @_canvas.width - pos, @_rulerHeight

    @_ctx.strokeStyle = @_ctx.fillStyle = MARKER_BG
    @_ctx.lineWidth = MARKER_WIDTH
    @_rulerTick time

    if marker.name.length > 0
      @_ctx.font = "bold #{FONT_SIZE}px #{FONT_FAMILY}"
      boxWidth = @_ctx.measureText(marker.name).width + (MARKER_WIDTH * 2)
      @_ctx.fillRect pos, @_rulerTop, boxWidth, FONT_SIZE

      @_ctx.fillStyle = MARKER_FG
      @_ctx.fillText marker.name, pos + MARKER_WIDTH, @_rulerTop + 2

  _rulerTick: (time, ruler = true) ->
    pos = @_timeToPx time
    labelYpos = if ruler then 0 else @_rulerBottom + 3

    @_snapPoints.push pos if ruler

    @_ctx.beginPath()
    @_ctx.moveTo pos, @_rulerTop
    @_ctx.lineTo pos, @_rulerBottom
    @_ctx.stroke()

    @_ctx.font = "#{FONT_SIZE}px #{FONT_FAMILY}"

    [oldFill, @_ctx.fillStyle] = [@_ctx.fillStyle, TIME_BACKGROUND]
    label = @_formatTime time, not ruler
    [labelXpos, labelWidth] = @_ensureVisible pos, label, not ruler
    @_ctx.fillRect labelXpos, labelYpos, labelWidth, FONT_SIZE
    @_ctx.fillStyle = oldFill
    @_ctx.fillText label, labelXpos, labelYpos + 1 # don't clip above the canvas top

  _ensureVisible: (pos, text, center) ->
    width = @_ctx.measureText(text).width
    pos -= width / 2 if center

    if (right = pos + width) > @_canvas.width
      pos -= right - @_canvas.width

    pos = Math.max 0, pos
    [pos, width]

  _outOfBounds: (dir) ->
    pos = PADDING
    pos = @_canvas.width - pos if dir == ALIGN_RIGHT

    height = @_rulerHeight / 2.5
    width = height
    top = (@_canvas.height - height) / 2

    @_ctx.lineWidth = 3

    @_ctx.beginPath()
    @_ctx.moveTo pos + (width * dir), top
    @_ctx.lineTo pos, top + (height / 2)
    @_ctx.lineTo pos + (width * dir), top + height
    @_ctx.stroke()

  _timeToPx: (time) ->
    time / @_scale

  _pxToTime: (px) ->
    px * @_scale

  _formatTime: (time, showMs) ->
    sign = if time < 0 then '-' else ''
    min = Math.abs time / 60
    sec = Math.abs time % 60
    ms = Math.abs time * 1000

    pad = (padding, int) ->
      int = Math.trunc int
      (padding + int).slice -padding.length

    out = "#{sign}#{pad '00', min}:#{pad '00', sec}"
    out += ".#{pad '000', ms}" if showMs
    out

  _snap: (pos) ->
    [min, max] = [-1, @_snapPoints.length]

    while max - min > 1
      i = Math.round((min + max) / 2)
      point = @_snapPoints[i]
      if point <= pos
        min = i
      else
        max = i

    min = @_snapPoints[min] - pos
    max = @_snapPoints[max] - pos
    distance = Math.min Math.abs(min), Math.abs(max)

    if distance < SNAP_THRESHOLD
      (if distance == Math.abs(min) then min else max) + pos
    else
      pos

  _isMouseOver: (x, y) ->
    x > 0 && x <= @_canvas.width && y > 0 && y <= @_canvas.height

  _mousePos: (e) ->
    if @_hasTouch
      e = e.touches[0] || e.changedTouches[0]

    x = e.pageX - @_canvas.offsetLeft
    y = e.pageY - @_canvas.offsetTop
    [x, y]

module.exports = Timeline
