root = exports ? this
Kinect = root.Kinect ? {}
root.Kinect = Kinect

#
# Provides well-defined interface to handle websocket-based connection.
#
class Kinect.Client
  constructor: (@socket_url) ->
    @socket = null
    @model = null
    @reset()

  #
  # Creates a new websocket which automatically tries to connect.
  # Resets whole state (except model).
  #
  connect: ->
    @socket = new JSONSocket(@socket_url)
    @reset()
    @bindListeners()
    @model.onConnecting() if @model

  #
  # Sets model instance to handle callbacks
  #
  # @param Kinect.Model model
  #
  setModel: (@model) ->
    # assignment has been done automatically

  #
  # Defines object types which are like categories of the elements.
  # Every category has :name, :width, :height.
  #
  # @param types Array
  #
  # Example:
  #   defineTypes([{ name: "animals-small-photo", width: 100, height: 50 }, { ... }])
  #
  defineTypes: (types, callback) ->
    @send('configure:object_types', types)

  #
  # Defines objects with their names and types.
  # All objects within a type have the same dimensions.
  # Every object has an unique name which is also a voice identifier.
  #
  # Object is like { name: String, type: String }
  #   :name - voice identifier
  #   :type - name of the type (defined earlier with configureObjectTypes)
  #
  # @param objects Array
  #
  # Example:
  #   defineTypes([{ name: "animals-small-photo", width: 100, height: 50 }, { ... }])
  #   defineElements([{ name: "lion", type: "animals-small-photo" }, { ... }])
  #
  defineElements: (objects) ->
    @send("configure:objects", objects)

  #
  # Defines size of the canvas and gutter - space between elements (when place using position relative to an element)
  #
  # @param sizing Object(width, height, gutter)
  #
  # Example:
  #   defineSizing({ width: 1280, height: 800, gutter: 20 })
  #
  defineSizing: (sizing) ->
    @send('configure:sizing', sizing)

  #
  # Inits calibration - server starts to listen for command "calibrate"
  #
  initCalibration: ->
    @send('calibration:listen_to_start')

  #
  # Inits work
  #
  initWork: ->
    @send('work:init')

  #
  # Tells server that active object has changed.
  #
  # @param name String|null - null to tell server that none object is active.
  #
  setActiveObject: (name) ->
    @send('object:set_active', { name: name || null })

  #
  # Checks whether connection has been ever successfully established.
  #
  hasBeenConnected: ->
    @everConnected

  #
  # Checks whether websocket is being connected right now.
  #
  isConnected: ->
    !@closed

  #
  # @private
  # Resets state of the connection. Clears all variables.
  #
  reset: ->
    @everConnected = false
    @closed = false

  #
  # @private
  #
  bindListeners: ->
    @bindConnectionListeners()
    @bindErrorListeners()
    @bindReconfigurationListeners()
    @bindCalibrationListeners()
    @bindWorkListeners()
    @passObjectManipulationToModel()

  #
  # @private
  #
  bindConnectionListeners: ->
    @socket.bind 'open', =>
      @everConnected = true
      @model.onOpen() if @model

    @socket.bind 'close', =>
      @closed = true
      @model.onClose() if @model

  #
  # @private
  #
  bindErrorListeners: ->
    @socket.bind 'error', (code) =>
      @model.onErrorOccured(code) if @model

    @socket.bind 'error:fixed', (code) =>
      @model.onErrorFixed(code) if @model

  #
  # @private
  #
  bindReconfigurationListeners: ->
    @socket.bind 'reconfigured:object_types', =>
      @model.onReconfiguration('object_types')

    @socket.bind 'reconfigured:objects', =>
      @model.onReconfiguration('objects')

    @socket.bind 'reconfigured:sizing', =>
      @model.onReconfiguration('sizing')

  #
  # @private
  #
  bindCalibrationListeners: ->
    @socket.bind 'calibration:start', (data) =>
      @model.onCalibrationStart(data.markers)
      @model.nextMarker(data.markers[0])

    @socket.bind 'calibration:next_marker', (data) =>
      @model.nextMarker(data.marker)

    @socket.bind 'calibration:done', =>
      @model.onCalibrationEnd()

  #
  # @private
  #
  bindWorkListeners: ->
    @socket.bind 'work:start', =>
      @model.onWorkStart()

  #
  # @private
  # Binds messages concerned about object manipulations (create, delete, update)
  # and passes them to model.
  #
  passObjectManipulationToModel: ->
    @socket.bind 'object:create', (attributes, event) =>
      @model.createElement(attributes) if @model

    @socket.bind 'object:remove', (data, event) =>
      @model.removeElement(data.name) if @model

    @socket.bind 'object:move', (data, event) =>
      @model.moveElementTo(data.name, { top: data.top, left: data.left }) if @model

  #
  # Sends data directly through the websocket.
  # Every message requires at least :type and :body.
  #
  send: (type, body) ->
    @connect() unless @isConnected()
    @socket.send(type, body)
