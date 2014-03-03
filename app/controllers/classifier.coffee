BaseController = require 'zooniverse/controllers/base-controller'
FauxRangeInput = require 'faux-range-input'

$ = window.jQuery
require '../lib/sample-data'

{CanvasGraph, Marks, Mark} = require "../lib/canvas-graph"

class Classifier extends BaseController
  className: 'classifier'
  template: require '../views/classifier'

  constructor: ->
    super

    @scaleSlider = new FauxRangeInput('#scale-slider')

    @canvas = @el.find('#graph')[0]
    @zoomBtn = @el.find('#toggle-zoom')[0]
    @marksContainer = @el.find('#marks-container')[0]
    @zoomBtn = @el.find('#toggle-zoom')[0]

    @canvasState = new CanvasGraph(@canvas, light_curve_data)
    @canvasState.plotPoints()

    @zoomBtn.addEventListener 'click', (e) => @onClickZoom()

  onClickZoom: ->
    @zoomed = !@zoomed
    if @zoomed then @canvasState.plotZoomedPoints(5,20) else @canvasState.rescale()

module.exports = Classifier