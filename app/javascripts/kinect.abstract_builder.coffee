root = exports ? this
Kinect = root.Kinect ? {}
root.Kinect = Kinect

#
# Abstract element builder for Kinect.Model.
# This class should be extended and provide an implemented version of the build method.
#
class Kinect.AbstractBuilder
  constructor: ->
    @templates = {}

  #
  # Defines templates for builder.
  # Everything passed under the key attributes
  # will be accessible for later use.
  #
  # Example:
  #   defineTemplates([
  #     { name: "lion", attributes: { color: "...", ... } }
  #   ])
  defineTemplates: (templates) ->
    @defineTemplate(template) for template in templates

  defineTemplate: (template) ->
    @templates[template.name] = template.attributes

  #
  # Builds an html element based on a template.
  #
  build: (element) ->
    template = @getTemplate(element.name)
    @buildFromTemplate(element, template)

  #
  # @private
  # Builds an html element based on a template.
  # Override this method so it returns a dom node using template as an attributes provider.
  #
  # @param element Object(name, ...) - instance of an element to be put on the work area
  # @param template Object(...) - all attributes defined under the :attributes key with defineTemplate(s) method.
  # @returns HTMLElement or one of its children, e.g. HTMLImageElement
  #
  buildFromTemplate: (element, template) ->
    # implemented in a derived class.

  #
  # @private
  #
  getTemplate: (name) ->
    @templates[name]