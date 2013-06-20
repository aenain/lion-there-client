root = exports ? this
Kinect = root.Kinect ? {}
root.Kinect = Kinect

class Kinect.ImageBuilder extends Kinect.AbstractBuilder
  # @override
  buildFromTemplate: (element, template) ->
    image = new Image()
    image.src = template.src
    image.classList.add("element")

    image