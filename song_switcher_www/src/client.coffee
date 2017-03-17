EXT_SECTION  = 'cfillion_song_switcher'
EXT_STATE    = 'state'
EXT_REL_MOVE = 'relative_move'
EXT_FILTER   = 'filter'
EXT_RESET    = 'reset'
CMD_UPDATE   = "TRANSPORT;MARKER;GET/EXTSTATE/#{EXT_SECTION}/#{EXT_STATE}"

EventEmitter = require('events').EventEmitter
equal = require 'deep-equal'

class State
  constructor: (data) ->
    if data then @unpack(data) else @fallback()

  unpack: (data) ->
    i = 0
    @currentIndex = parseInt data[i++]
    @songCount = parseInt data[i++]
    @title = data[i++]
    @startTime = parseFloat data[i++]
    @endTime = parseFloat data[i++]
    @invalid = data[i++] == 'true'

  fallback: ->
    @currentIndex = @songCount = @startTime = @endTime = 0
    [@title, @invalid] = ['## No data from Song Switcher ##', true]

class Marker
  constructor: (data) ->
    i = 1
    @name = data[i++]
    @id = data[i++]
    @time = parseFloat data[i++]
    @color = parseInt data[i++]

    @name ||= @id

class Client extends EventEmitter
  makeSetExtState = (key, value) ->
    "SET/EXTSTATE/#{EXT_SECTION}/#{key}/#{encodeURIComponent value}"

  constructor: (timer) ->
    @data = {}
    (fetch_loop = =>
      @send ''
      setTimeout fetch_loop, timer
    )()

  play: ->
    @send 40044 # Transport: Play/stop

  relativeMove: (move) ->
    @send makeSetExtState(EXT_REL_MOVE, move)

  setFilter: (filter) ->
    @send makeSetExtState(EXT_FILTER, filter)
  
  seek: (time) ->
    @send "SET/POS/#{time}"

  panic: ->
    @send 40345 # Send all notes off to all MIDI outputs/plug-ins

  reset: ->
    @send makeSetExtState(EXT_RESET, 'true')

  send: (cmd) ->
    req = new XMLHttpRequest
    req.onreadystatechange = =>
      if(req.readyState == XMLHttpRequest.DONE)
        if req.status == 200
          @parse req.responseText
        else
          @eraseData()
    req.open 'GET', "/_/#{cmd};#{CMD_UPDATE}", true
    req.send null

  eraseData: ->
    @editData (set) ->
      set 'playState', false
      set 'position', 0
      set 'state', new State

  parse: (response) ->
    markers = []
    @editData (set) ->
      for l in response.split('\n')
        tok = l.split '\t'

        switch tok[0]
          when 'TRANSPORT'
            set 'playState', tok[1] != '0'
            set 'position', parseFloat(tok[2])
          when 'MARKER'
            markers.push new Marker(tok)
          when 'EXTSTATE'
            if tok[1] == EXT_SECTION && tok[2] == EXT_STATE
              set 'state', if tok[3].length
                new State simple_unescape(tok[3]).split('\t')
              else
                new State
      set 'markerList', markers

  editData: (cb) ->
    modified = []
    cb (key, value) =>
      unless equal @data[key], value
        @data[key] = value
        modified.push key
    @emit "#{key}Changed", @data[key] for key in modified

module.exports = Client
