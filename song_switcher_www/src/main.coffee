Client = require './client'
Timeline = require './timeline'

class SongSwitcherWWW
  constructor: ->
    @_client = new Client 100

    @_timeline = new Timeline document.getElementById('timeline')
    @_lockOverlay = document.getElementById 'lock-overlay'

    @_ctrlBar  = document.getElementById 'controls'
    @_prevBtn  = document.getElementById 'prev'
    @_nextBtn  = document.getElementById 'next'
    @_playBtn  = document.getElementById 'play'
    @_panicBtn = document.getElementById 'panic'
    @_resetBtn = document.getElementById 'reset'
    @_lockBtn  = document.getElementById 'lock'
    @_songBox  = document.getElementById 'song_box'
    @_songName = document.getElementById 'title'
    @_filter   = document.getElementById 'filter'

    @_setText @_songName, '## Awaiting data ##'
    @_setClass @_ctrlBar, 'invalid', false
    @_timeline.update @_client.data

    @_client.on 'playStateChanged', (state) =>
      @_setClass @_playBtn, 'active', state > 0
      @_setClass @_playBtn, 'record', state & 4
      @_setClass @_playBtn, 'paused', state & 2
    @_client.on 'stateChanged', (state) =>
      @_setVisible @_prevBtn, state.currentIndex > 1
      @_setVisible @_nextBtn, state.currentIndex < state.songCount
      @_setClass @_ctrlBar, 'invalid', state.invalid
      @_setText @_songName, state.title
      @_timeline.update @_client.data
    @_client.on 'positionChanged', => @_timeline.update @_client.data
    @_client.on 'markerListChanged', => @_timeline.update @_client.data

    @_timeline.on 'seek', (time) => @_client.seek time

    @_prevBtn.addEventListener 'click', => @_client.relativeMove -1
    @_nextBtn.addEventListener 'click', => @_client.relativeMove 1
    @_playBtn.addEventListener 'click', => @_client.play()
    @_panicBtn.addEventListener 'click', => @_client.panic()
    @_resetBtn.addEventListener 'click', => @_client.reset()
    @_lockBtn.addEventListener 'click', =>
      if !@_isLocked() || confirm('Are you sure?')
        @_lockOverlay.classList.toggle 'hidden'
        @_lockBtn.classList.toggle 'active'
    @_songName.addEventListener 'click', =>
      @_setClass @_songBox, 'edit', true
      @_filter.focus()
    @_filter.addEventListener 'blur', => @_closeFilter()
    @_filter.addEventListener 'keypress', (e) =>
      if e.keyCode == 8 && !@_filter.value.length
        @_closeFilter()
      else if(e.keyCode != 13)
        return

      if(@_filter.value.length > 0)
        @_client.setFilter @_filter.value

      @_closeFilter()

    window.addEventListener 'resize', => @_timeline.update @_client.data
    window.addEventListener 'keydown', (e) =>
      if !@_isLocked() && e.keyCode == 32 && e.target == document.body
        @_client.play()
    window.addEventListener 'beforeunload', (e) =>
      if @_isLocked()
        text = 'Are you sure?'
        e.returnValue = text

  _setText: (node, text) ->
    if(textNode = node.lastChild)
      textNode.nodeValue = text
    else
      node.appendChild document.createTextNode(text)

  _setClass: (node, klass, enable = true) ->
    if(enable)
      node.classList.add klass
    else
      node.classList.remove klass

  _setVisible: (node, visible) ->
    @_setClass node, 'hidden', !visible

  _closeFilter: ->
    @_setClass @_songBox, 'edit', false
    @_filter.value = ''
    document.activeElement.blur() # close android keyboard

  _isLocked: ->
    @_lockBtn.classList.contains 'active'

module.exports = SongSwitcherWWW
