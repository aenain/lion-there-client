root = exports ? this
Kinect = {}
root.Kinect = Kinect

#
# Custom element builder for Kinect.Model.
#
class Kinect.ElementBuilder
  constructor: ->
    @elementTemplates = {}

  #
  # Defines elements for builder.
  #
  # Example:
  #   defineElements([
  #     { name: "lion", attributes: { src: "..." } }
  #   ])
  defineElements: (elements) ->
    @defineElement(element) for element in elements

  defineElement: (element) ->
    @elementTemplates[element.name] = element.attributes

  build: (element) ->
    elementTemplate = @elementTemplates[element.name]
    htmlElement = new Image()
    htmlElement.src = elementTemplate.src

    htmlElement


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
      @model.removeElement(data.id) if @model

    @socket.bind 'object:move', (data, event) =>
      @model.moveElementTo(data.id, { top: data.top, left: data.left }) if @model

  #
  # Sends data directly through the websocket.
  # Every message requires at least :type and :body.
  #
  send: (type, body) ->
    @connect() unless @isConnected()
    @socket.send(type, body)

class Kinect.Model
  constructor:  (@socket_url) ->
    @definitions =
      types: []
      elements: []
      sizing:
        gutter: 0
        height: window.innerHeight
        width: window.innerWidth

    @configured =
      object_types: false
      objects: false
      sizing: false

    @timeouts =
      activeElement: null

    @currentMarker = null

    @elements = {}
    @activeElement = null
    @elementBuilder = null
    @errors = []

    @client = new Kinect.Client(@socket_url)
    @client.setModel(this)

    @view = new Kinect.View(this)

  init: ->
    @view.resizeLayersToFitScreen()
    @connect()

  defineTypes: (types) ->
    # TODO! validate types
    @definitions.types = types

  defineElements: (elements) ->
    # TODO! validate elements
    @definitions.elements = elements

  setGutter: (gutter) ->
    @definitions.sizing.gutter = gutter || 0

  setBuilder: (builder) ->
    @elementBuilder = builder

  connect: ->
    @client.connect()

  configure: ->
    @view.displayLoader('Configuring')

    @client.defineTypes(@definitions.types)
    @client.defineElements(@definitions.elements)
    @client.defineSizing(@definitions.sizing)

  isConfigured: ->
    @configured.object_types && @configured.objects && @configured.sizing

  onConnecting: ->
    # TODO! reset state?
    @view.displayLoader('Connecting')

  onOpen: ->
    @configure()

  onClose: ->
    if @client.hasBeenConnected()
      @view.displayErrorByType('connection_lost')
    else
      @view.displayErrorByType('cant_connect')

  onReconfiguration: (type) ->
    @configured[type] = true
    if @isConfigured()
      @view.displayWelcomeScreen()
      @client.initCalibration()

  #
  # Handler called when server is ready to start calibration.
  # @param markers Array  - list of markers which will be used during the calibration.
  #                         Valid markers:
  #                         "top left", "top", "top right", "right", "bottom right", "bottom", "bottom left", "left"
  onCalibrationStart: (markers) ->
    @view.createMarkers(markers)
    @view.displayCalibrator()

  onCalibrationEnd: ->
    @client.initWork()

  #
  # Moves to the next marker during the configuration.
  # Hides currentMarker (if any), highlights the next marker by id
  #
  nextMarker: (markerId) ->
    @view.markMarkerAsLocked(@currentMarker) if @currentMarker
    @currentMarker = markerId
    @view.highlightMarker(markerId)

  onWorkStart: ->
    @view.displayWorkArea()

  onErrorOccured: (code) ->
    @addErrorByCode(code)
    @view.displayErrorByCode(code)

  onErrorFixed: (code) ->
    @removeErrorByCode(code)

    if @errorsPresent()
      code = @errors[@errors.length - 1]
      @view.displayErrorByCode(code)
    else
      @view.hideError()

  errorsPresent: ->
    ! @errors.length

  addErrorByCode: (code) ->
    @errors.push(code)

  removeErrorByCode: (code) ->
    @errors = @errors.filter (error) ->
      error != code

  createElement: (elementAttrs) ->
    type = @findType(elementAttrs.type)
    throw "element type: #{elementType} is undefined!" unless type

    attributes = _.extend({ width: type.width, height: type.height }, elementAttrs)
    element = @elementBuilder.build(attributes)
    @view.addElement(element, attributes)

    @elements[attributes.id] =
      attributes: attributes
      html: element

  removeElement: (id) ->
    element = @elements[id]
    delete @elements[id]
    @view.removeElement(element.html)

  moveElementTo: (id, centerLocation) ->
    element = @elements[id]
    @view.moveElement(element.html, { center: { top: centerLocation.top, left: centerLocation.left }})

  setActiveElement: (@activeElement) ->
    clearTimeout(@timeouts.activeElement)
    @timeouts.activeElement = setTimeout =>
      @client.setActiveObject(@activeElement)
    , 5

  #
  # @private
  #
  findType: (name) ->
    for type in @definitions.types
      if type.name == name
        return type

    return null

#
# Manager of the DOM.
# Required html structure:
# <div class="full-screen">
#   <!-- error layer -->
#   <div class="layer" id="error">
#     <h2 data-dest="description"></h2>
#     <p data-dest="hint"></p>
#   </div>
#   <!-- loading layer -->
#   <div class="layer" id="loading">
#     <h2 data-dest="description"></h2>
#   </div>
#   <!-- welcome screen -->
#   <div class="layer" id="welcome-screen"></div>
#   <!-- calibration layer -->
#   <div class="layer" id="calibration">
#     <!-- markers are going to be created automatically -->
#   </div>
#   <div class="layer" id="work-area">
#     <img src="..." data-dest="element" />
#     <!-- more images -->
#   </div>
# </div>
#
class Kinect.View
  @ERRORS =
    cant_connect:
      description: ""
      hint: ""

    connection_lost:
      description: "Connection lost."
      hint: "no hint..."

    undefined_error:
      description: "An unknown error has occured."
      hint: "Please contact the development team."

  @ERROR_CODES =
    code_1: 'cant_connect'
    code_2: 'connection_lost'

  constructor: (@model) ->
    @workArea = document.querySelector('#work-area')
    @markers = {}
    @layers =
      active:
        id: null
        element: null
      previous:
        id: null
        element: null

  resizeLayersToFitScreen: ->
    viewportSize =
      height: window.innerHeight
      width: window.innerWidth

    fullScreen = document.querySelector(".full-screen")
    fullScreen.style.height = viewportSize.height + 'px'

    layers = document.querySelectorAll(".full-screen .layer")
    for layer in layers
      layer.style.height = viewportSize.height + 'px'
      layer.style.width = viewportSize.width + 'px'

  addElement: (element, attributes) ->
    element = @setElementRequiredAttributes(element, attributes)

    @workArea.appendChild(element)
    @moveElement(element, {
      center: {
        top: attributes.top
        left: attributes.left
      }
    })
    @bindActiveElementTracker(element)

    element

  removeElement: (htmlElement) ->
    # TODO! maybe add some animations?
    htmlElement.remove()

  moveElement: (htmlElement, location) ->
    htmlElement.style.top = location.center.top + 'px'
    htmlElement.style.left = location.center.left + 'px'

  #
  # @private
  #
  setElementRequiredAttributes: (element, attributes) ->
    style = """
      margin-top: #{-attributes.height / 2}px;
      margin-left: #{-attributes.width / 2}px;
      width: #{attributes.width}px;
      height: #{attributes.height}px;
      position: absolute
    """
    element.setAttribute('style', style)
    element.setAttribute('data-name', attributes.name)

    element

  #
  # @private
  # Builds html node of a marker
  # @param attributes Object(classes)
  #
  buildMarkerElement: (attributes) ->
    element = document.createElement('div')
    element.classList.add(cssClass) for cssClass in attributes.classes

    element

  #
  # @private
  # Binds active element tracking to an element.
  # @param element HTMLElement
  #
  bindActiveElementTracker: (element) ->
    element.onmouseover = (event) =>
      @model.setActiveElement(element.dataset.name)
    element.onmouseout = (event) =>
      @model.setActiveElement(null)

  #
  # Creates HTML Nodes for markers (identifiers are from server)
  #
  createMarkers: (markers) ->
    calibrationArea = document.querySelector('#calibration')

    for markerId in markers
      classes = @mapMarkerIdToCssClasses(markerId)
      marker = @buildMarkerElement({ classes: classes })
      calibrationArea.appendChild(marker)
      @markers[markerId] = marker

  #
  # Marks marker as locked.
  # Before going to the next mark the last one should be marked as locked because it can't be changed.
  #
  markMarkerAsLocked: (markerId) ->
    marker = @markers[markerId]
    marker.classList.add('locked')
    @unbindInstructionChangeOverMarker(marker)

  #
  # Highlights a marker to work with (moving cursor over it).
  # It also binds mouseover i mouseout events to provide a clearer instruction for user.
  #
  highlightMarker: (markerId) ->
    marker = @markers[markerId]
    marker.classList.add('highlight')
    @bindInstructionChangeOverMarker(marker)

  #
  # Displays the loader layer with the passed message.
  #
  displayLoader: (message) ->
    @updateLayer('loading', { description: message || "" })
    @changeActiveLayer('loading')

  displayWelcomeScreen: ->
    @changeActiveLayer('welcome-screen')

  displayWorkArea: ->
    @changeActiveLayer('work-area')

  displayErrorByType: (type) ->
    error = @getErrorByType(type)
    @displayError(error)

  displayErrorByCode: (code) ->
    error = @getErrorByCode(code)
    @displayError(error)

  #
  # Displays error using its description and hint if any.
  #
  # @param error Object(description, hint)
  #
  displayError: (error) ->
    @updateLayer('error', { description: error.description, hint: error.hint })
    @changeActiveLayer('error')

  #
  # Hides the error layer and displays the one displayed before.
  #
  hideError: ->
    @changeActiveLayer(@layers.previous.id)

  displayCalibrator: ->
    @changeActiveLayer('calibration')

  #
  # @private
  # Maps marker identificators from server to css classes
  #
  mapMarkerIdToCssClasses: (markerId) ->
    classes = ["marker"]

    if /\b\s+\b/.test(markerId)
      classes.concat(markerId.split(/\s+/))
    else
      classes.concat([markerId, "middle"])

  #
  # @private
  #
  bindInstructionChangeOverMarker: (marker) ->
    marker.onmouseover = (event) ->
      instruction = document.querySelector('#calibration .interchangeable-container')
      instruction.classList.add('change')
    marker.onmouseout = (event) ->
      instruction = document.querySelector('#calibration .interchangeable-container')
      instruction.classList.remove('change')

  #
  # @private
  #
  unbindInstructionChangeOverMarker: (marker) ->
    marker.onmouseout()
    marker.onmouseover = null
    marker.onmouseout = null

  #
  # @private
  # Within a DOM Node identified by layerId finds elements to populate:
  # data-dest is equal to a key from data.
  #
  updateLayer: (layerId, data) ->
    layer = document.querySelector('#' + layerId)
    for own dest, text of data || {}
      element = layer.querySelector("[data-dest='#{dest}']")
      element.innerText = text 

  #
  # @private
  # Top-level layers changing
  #
  changeActiveLayer: (layerId) ->
    @storePreviousLayer()
    @setActiveLayerById(layerId)
    @transitLayers()

  #
  # @private
  #
  storePreviousLayer: ->
    @layers.previous.id = @layers.active.id
    @layers.previous.element = @layers.active.element

  #
  # @private
  #
  setActiveLayerById: (layerId) ->
    @layers.active.id = layerId
    @layers.active.element = document.querySelector('#' + layerId)

  #
  # @private
  # Does a visual transition between layers.
  #
  transitLayers: ->
    previousLayer = @layers.previous.element ? document.querySelector('.layer.active')
    currentLayer = @layers.active.element
    previousLayer.classList.remove('active') if previousLayer
    currentLayer.classList.add('active')

  #
  # @private
  #
  getErrorByCode: (code) ->
    type = Kinect.View.ERROR_CODES["code_#{code}"]
    @getErrorDataByType(type)

  #
  # @private
  #
  getErrorByType: (type) ->
    Kinect.View.ERRORS[type] ? Kinect.View.ERRORS.undefined_error