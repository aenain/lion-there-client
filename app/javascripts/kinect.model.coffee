root = exports ? this
Kinect = root.Kinect ? {}
root.Kinect = Kinect

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

    @elements[attributes.name] =
      attributes: attributes
      html: element

  removeElement: (name) ->
    element = @elements[name]
    delete @elements[name]
    @view.removeElement(element.html)

  moveElementTo: (name, centerLocation) ->
    element = @elements[name]
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