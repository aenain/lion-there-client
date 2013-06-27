root = exports ? this
Kinect = root.Kinect ? {}
root.Kinect = Kinect

#
# One of the possible implementations of the elements builder
# used by Kinect.Model.
#
class Kinect.ImageBuilder extends Kinect.AbstractBuilder
  # @override
  buildFromTemplate: (element, template) ->
    image = new Image()
    image.src = template.src
    image.classList.add("element")

    image