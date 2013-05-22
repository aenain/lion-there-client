root = exports ? this

# Encapsulates raw websocket and provides communication with JSON objects.
# Provides interface for building a simple application using WebSocket.
#
# Requires message to be a serialized json to string with two keys defined: type and message, e.g.
#   { type: "message_type", message: "actual_message" }
# both type and message can be objects as well.
#
# Usage:
#   # opens a new websocket
#   socket = new JSONSocket("ws://localhost:8080/")
#
#   # listens to typical events (onopen, onmessage, onclose)
#   socket.bind 'open', -> console.log('open')
#   socket.bind 'message', (type, message, event) -> console.log('message received!' type: ' + type)
#   socket.bind 'close', -> console.log('close')
#
#   # listens only to a custom message type (onmessage)
#   socket.bind 'my_type', (message, event) -> console.log('message received! type: my_type')
#
#   # sends a message with a custom content and type: my_type
#   socket.send('my_type', { severity: 10 })
#
#   # closes websocket
#   socket.close()
#
root.JSONSocket = class JSONSocket
  constructor: (@url) ->
    @_socket = new WebSocket(@url)
    @_callbacks = {}
    @_bindInterceptor()

  bind: (event, callback) ->
    @_callbacks[event] = callback

  trigger: (event, args) ->
    @_callbacks[event]?.apply(@, args)

  close: ->
    @_socket.close()

  send: (type, message) ->
    json = JSON.stringify({ type: type, message: message })
    @_socket.send(json)

  _bindInterceptor: ->
    @_socket.onopen = =>
      @trigger('open')

    @_socket.onclose = =>
      @trigger('close')

    @_socket.onmessage = (event) =>
      data = JSON.parse(event.data)
      @trigger('message', [data.type, data.message, event])
      @trigger(data.type, [data.message, event])