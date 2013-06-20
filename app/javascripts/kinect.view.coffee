root = exports ? this
Kinect = root.Kinect ? {}
root.Kinect = Kinect

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
      description: "Can't connect to the server."
      hint: "Please make sure if server is running a websocket."

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
    htmlElement.remove()

  # TODO! setActiveElement accordingly if necessary
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
    setTimeout ->
      instruction = document.querySelector('#calibration .interchangeable-container')
      instruction.classList.add('change')
    , 1000

  #
  # @private
  #
  unbindInstructionChangeOverMarker: (marker) ->
    instruction = document.querySelector('#calibration .interchangeable-container')
    instruction.classList.remove('change')

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