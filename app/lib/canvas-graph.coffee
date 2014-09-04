class CanvasGraph

  DEBUG = false

  constructor: (@canvas, @data) ->
    @leftPadding = 60
    @showAxes    = true
    @ctx = @canvas.getContext('2d')
    @highlights = []

    @dataLength = Math.min @data.x.length, @data.y.length

    # save raw data points
    @data_raw = {}
    @data_raw.x = @data.x.slice(0)
    @data_raw.y = @data.y.slice(0)


    # initialize zoom parameters
    @zoomRanges = [@largestX, 10, 2]
    @zoomLevel = 0
    @graphCenter = 5

    # apply normalization, outlier removal, etc.
    @processLightcurve()

  disableMarking: ->
    # console.log 'CANVAS GRAPH: disableMarking()'
    @markingDisabled = true

  enableMarking: ->
    # console.log 'CANVAS GRAPH: enableMarking()'
    @markingDisabled = false
    
    # TODO: should this be in the constructor?
    @marks = new Marks
    window.marks = @marks
    @canvas.addEventListener 'mousedown', (e) => @onMouseDown(e)
    @canvas.addEventListener 'touchstart', (e) => @addMarkToGraph(e)
    @canvas.addEventListener 'mousemove', (e) => @onMouseMove(e) # TODO: FIX (disabled for now)

  onMouseDown: (e) =>
    # debugger
    # console.log 'onMouseDown()'
    xClick = e.pageX - e.target.getBoundingClientRect().left - window.scrollX
    return if xClick < 80 # display line instead 
    @addMarkToGraph(e)

  onMouseMove: (e) =>
    # return # just for now
    return if @markingDisabled
    return if classifier.el.find('#graph').hasClass('is-zooming')
    @sliderValue = +classifier.el.find("#ui-slider").val()
    xClick = e.pageX - e.target.getBoundingClientRect().left - window.scrollX
    yClick = e.pageY - e.target.getBoundingClientRect().top - window.scrollY

    # @plotPoints(@sliderValue, @sliderValue+@zoomRanges[@zoomLevel])

    # if xClick < @leftPadding
    #   # draw triangle
    #   w = 10
    #   s = 2*w*Math.tan(@leftPadding)
      
    #   @ctx.beginPath()
    #   @ctx.moveTo(w,yClick)
    #   @ctx.lineTo(0,yClick+s)
    #   @ctx.lineTo(0,yClick-s)
    #   @ctx.fillStyle = '#FC4542'      
    #   @ctx.fill()

    #   @ctx.beginPath()
    #   @ctx.moveTo(w,yClick)
    #   @ctx.lineWidth = 1
    #   @ctx.strokeStyle = 'rgba(252,69,66,0.9)'
    #   @ctx.moveTo( 60, yClick )
    #   @ctx.lineTo( @canvas.width, yClick )
    #   @ctx.moveTo( 0, yClick )
    #   @ctx.lineTo( 10, yClick )
    #   @ctx.stroke()

    #   @ctx.font = '10pt Arial'
    #   @ctx.textAlign = 'left'
    #   @ctx.fillText( @toDataYCoord((-yClick+@canvas.height)).toFixed(4), 15, yClick+5 ) # don't forget to flip y-axis values
    
  processLightcurve: (removeOutliers=false) ->

    @removeOutliers = removeOutliers

    # classifier.el.find("#ui-slider").val(0) # reset slider value
    # @zoomOut()

    # restore original values
    @data.x = @data_raw.x
    @data.y = @data_raw.y

    # this step is necessary or (top) x-axis breaks
    @smallestX = Math.min @data_raw.x...
    @originalMin = @smallestX
    for x, i in [@data.x...]
      @data.x[i] = x - @smallestX

    if removeOutliers
      @data = @processOutliers(@data_raw, nsigma=3) # NOTE: nsigma < 8 removes tutorial subject transits
    
    @data.y = @normalize(@data.y)

    # update min/max values
    @smallestX = Math.min @data.x...
    @smallestY = Math.min @data.y...
    @largestX = Math.max  @data.x...
    @largestY = Math.max  @data.y...

    @plotPoints()
    
    return

  toggleOutliers: ->
    @removeOutliers = !@removeOutliers
    @processLightcurve(@removeOutliers)
    return

  normalize: (data) ->
    y_new = []
    mean = @mean(data)
    std = @std(data)

    for y, i in [ data... ]
      y_new[i] = (y-1)/(std)
      y_new[i] = y/(mean)
     
    return y_new

  processOutliers: (data, nsigma) -> 
    data_new = {}
    data_new.x = []
    data_new.y = []
    mean = @mean(data.y)
    std = @std(data.y)
    
    for y, i in [data.y...]
      continue if (y - mean) > (nsigma * std) # skip outlier
      data_new.x.push data.x[i]
      data_new.y.push data.y[i]

    return data_new

  std: (data) ->
    mean = @mean(data)
    sum = 0
    for value in data
      sum = sum + Math.pow( Math.abs(mean-value), 2 )
    return Math.sqrt( sum / data.length )

  mean: (data) ->
    sum = 0
    for value in data
      sum = sum + value
    return sum / data.length

  showFakePrevMarks: () ->
    # console.log 'showFakePrevMarks()'
    @zoomOut()
    maxMarks = 5
    minMarks = 1 
    howMany = Math.floor( Math.random() * (maxMarks-minMarks) + minMarks )
    # console.log 'randomly generating ', howMany, ' (fake) marks' # DEBUG
    @generateFakePrevMarks( howMany )
    for entry in [@prevMarks...]
      # console.log '[',entry.xL,',',entry.xR,']' # DEBUG
      @highlightCurve(entry.xL,entry.xR)

  generateFakePrevMarks: (n) ->
    minWid = 0.5 # [days]
    maxWid = 3.0
    xPos = []
    wid = []
    @prevMarks = []
    for i in [0...n]
      wid[i] = Math.random() * ( maxWid - minWid ) + minWid
      xPos[i] = Math.random() * (36-1) + 1
      @prevMarks[i] = { xL: xPos[i]-wid[i]/2, xR: xPos[i]+wid[i]/2 }

  showPrevMarks: ->
    $('#graph-container').addClass('showing-prev-data')
    for entry in [@prevMarks...]
      # console.log '[',entry.xL,',',entry.xR,']' # DEBUG
      @highlightCurve(entry.xL,entry.xR)

  highlightCurve: (xLeft,xRight) ->
    @highlights.push {'xLeft': xLeft, 'xRight': xRight}
    @plotPoints()

  drawHighlights: ->
    sliderOffset = ( (@xMin) / (@xMax - @xMin) ) * ( @canvas.width-@leftPadding )

    for highlight in [ @highlights... ]
      for i in [0...@dataLength]
        if @data.x[i] >= highlight.xLeft and @data.x[i] <= highlight.xRight
          x = ((+@data.x[i]+@toDays(@leftPadding)-@xMin)/(@xMax-@xMin)) * (@canvas.width-@leftPadding)
          y = ((+@data.y[i]-@yMin)/(@yMax-@yMin)) * @canvas.height
          y = -y + @canvas.height # flip y-values
          # @ctx.beginPath()
          @ctx.fillStyle = "rgba(252, 69, 65, 1.0)" #"#fc4541"
          continue if x-sliderOffset < 60 # skip if overlap with y-axis
          @ctx.fillRect(x-sliderOffset,y,2,2)

  plotPoints: (xMin = @smallestX, xMax = @largestX, yMin = @smallestY, yMax = @largestY) ->
    @xMin = xMin
    @xMax = xMax
    @yMin = yMin
    @yMax = yMax
    @clearCanvas()

    # get necessary values from classifier
    @sliderValue = +classifier.el.find('#ui-slider').val()
    
    # draw points
    for i in [0...@dataLength]
      x = ((+@data.x[i]-xMin)/(xMax-xMin)) * (@canvas.width-@leftPadding)
      continue if x < 0 # don't plot points past margin
      y = ((+@data.y[i]-yMin)/(yMax-yMin)) * @canvas.height
      y = -y + @canvas.height # flip y-values
      @ctx.fillStyle = "#fff" #fc4541"
      @ctx.fillRect(x+@leftPadding,y,2,2)

    @drawHighlights()

    if $('#graph-container').hasClass('showing-prev-data')
      @showPrevMarks()

    # draw axes
    if @showAxes
      @drawXTickMarks(xMin, xMax)
      @drawYTickMarks(yMin, yMax)

    @scale = (parseFloat(@largestX) - parseFloat(@smallestX)) / (parseFloat(@xMax) - parseFloat(@xMin))
    @rescaleMarks(xMin, xMax)

    return

  rescaleMarks: (xMin, xMax) ->
    # console.log 'RESCALING MARKS.....'
    if @zoomLevel is 0
      @sliderValue = 0
    else
      @sliderValue = +classifier.el.find('#ui-slider').val()
    
    # draw marks
    if @marks
      for mark in @marks.all
        scaledMin = ((parseFloat(mark.dataXMinRel) + parseFloat(@toDays(@leftPadding)) - parseFloat(xMin) - parseFloat(@sliderValue) ) / (parseFloat(xMax) - parseFloat(xMin)) ) * parseFloat(@canvas.width-@leftPadding)
        scaledMax = ((parseFloat(mark.dataXMaxRel) + parseFloat(@toDays(@leftPadding)) - parseFloat(xMin) - parseFloat(@sliderValue) ) / (parseFloat(xMax) - parseFloat(xMin)) ) * parseFloat(@canvas.width-@leftPadding)
        #                                ^ prevents from moving towards left                          ^ prevents marks from moving towards right
        mark.element.style.width = (parseFloat(scaledMax)-parseFloat(scaledMin)) + "px"
        mark.element.style.left = parseFloat(scaledMin) + "px"
        mark.save(scaledMin, scaledMax)

    @scale = (@largestX - @smallestX) / (@xMax - @xMin)
    return

  zoomOut: (callback) ->
    # classifier.el.find('#graph').addClass('is-zooming')

    @zoomLevel = 0

    # update slider position
    classifier.el.find('#ui-slider').val(@graphCenter-@zoomRanges[@zoomLevel]/2)
    
    @plotPoints(@smallestX, @largestX)

    [cMin, cMax] = [@xMin, @xMax]
    [wMin, wMax] = [@smallestX, @largestX]

    classifier.el.find("#zoom-button").removeClass("zoomed")
    classifier.el.find("#zoom-button").removeClass("allowZoomOut") # for last zoom level
    classifier.el.find('#ui-slider').attr('disabled',true)
    classifier.el.find('.noUi-handle').fadeOut(150)


    # TODO: broken (a major pain in my ass)
    # step = 1.5
    # zoom = setInterval (=>
      
    #   # gradually expand zooming bounds
    #   cMin -= step
    #   if cMin < @smallestX then cMin = @smallestX
    #   cMax += step
    #   if cMax > @largestX then cMax = @largestX
      
    #   # console.log "[cMin,cMax] = [#{cMin},#{cMax}]"
    #   @plotPoints(cMin,cMax)

    #   if cMin <= @smallestX and cMax >= @largestX  # finished zooming
    #     clearInterval zoom
    #     classifier.el.find('#graph').removeClass('is-zooming')
    #     @plotPoints(@smallestX, @largestX)
    #     unless callback is undefined 
    #       callback.apply()
    #       classifier.el.find("#zoom-button").removeClass("zoomed")
    #       classifier.el.find("#zoom-button").removeClass("allowZoomOut") # for last zoom level
    #       classifier.el.find('#ui-slider').attr('disabled',true)
    #       classifier.el.find('.noUi-handle').fadeOut(150)
    # ), 30
    # return


  zoomToCenter: (center) ->
    console.log 'zoomToCenter, CENTER = ', center
    # classifier.el.find('#graph').addClass('is-zooming')
    boundL = center - @zoomRanges[@zoomLevel]/2
    boundR = center + @zoomRanges[@zoomLevel]/2

    # ensure zooming within bounds
    if boundL < @smallestX
      boundL = @smallestX
      boundR = @smallestX + @zoomRanges[@zoomLevel]/2
      console.log "ENFORCING BOUNDS: [#{boundL},#{boundR}] (exceeded left bound)"

    if boundR > @largestX
      boundR = @largestX
      boundL = @largestX - @zoomRanges[@zoomLevel]/2
      console.log "ENFORCING BOUNDS: [#{boundL},#{boundR}] (exceeded right bound)"

    # update slider position
    classifier.el.find('#ui-slider').val(boundL)
    console.log "ZOOMING TO: [#{boundL},#{boundR}] (exceeded right bound)"

    console.log 

    @plotPoints(boundL,boundR)

    # console.log "ZOOM TO CENTER: [#{left},#{right}]"    

    # [cMin, cMax] = [@xMin, @xMax]

    # zoom = setInterval (=>
    #   @plotPoints(cMin,cMax)
    #   @rescaleMarks(cMin,cMax)
    #   cMin += 1.5 unless cMin >= wMin
    #   cMax -= 1.5 unless cMax <= wMax
    #   if cMin >= wMin and cMax <= wMax # when 'animation' is done...
    #     clearInterval zoom
    #     classifier.el.find('#graph').removeClass('is-zooming')
    #     @plotPoints(wMin,wMax)
    #     @resc


  zoomInTo: (wMin, wMax) ->
    classifier.el.find('#graph').addClass('is-zooming')
    [cMin, cMax] = [@xMin, @xMax]

    zoom = setInterval (=>
      @plotPoints(cMin,cMax)
      @rescaleMarks(cMin,cMax)
      cMin += 1.5 unless cMin >= wMin
      cMax -= 1.5 unless cMax <= wMax
      if cMin >= wMin and cMax <= wMax # when 'animation' is done...
        clearInterval zoom
        classifier.el.find('#graph').removeClass('is-zooming')
        @plotPoints(wMin,wMax)
        @rescaleMarks(wMin,wMax)
    ), 30

  drawXTickMarks: (xMin, xMax) ->
    # tick/text properties
    tickMinorLength = 5
    tickMajorLength = 10
    tickWidth = 1
    tickColor = '#323232'
    textColor = '#323232'
    textSpacing = 15

    # determine intervals
    xMag = Math.round( Math.abs(xMin-xMax) )
    if xMag <= 2 # days
      majorTickInterval = 4
      minorTickInterval = 16
      textInterval = 8
    else if xMag <= 10 # days
      majorTickInterval = 4
      minorTickInterval = 4
      textInterval = 4
    else # all days
      majorTickInterval = 2
      minorTickInterval = 1
      textInterval = 2

    # generate intervals
    xTicks = []
    xStep = 1/minorTickInterval
    i = 0
    xVal = Math.floor(xMin)
    while xVal <= Math.ceil(xMax)
      for j in [0...minorTickInterval]
        tick = xVal + j*xStep;
        unless tick > Math.ceil(xMax)
          xTicks.push tick
      i++
      xVal++

    for tick, i in [xTicks...]
      continue if i is 0 # skip first value

      # draw ticks (bottom)
      @ctx.beginPath() 
      @ctx.moveTo( @toPixels(tick)+@leftPadding, @canvas.height )
      if i % majorTickInterval is 0
        @ctx.lineTo( @toPixels(tick)+@leftPadding, @canvas.height - tickMajorLength ) # major tick
      else
        @ctx.lineTo( @toPixels(tick)+@leftPadding, @canvas.height - tickMinorLength ) # minor tick
      @ctx.lineWidth = tickWidth
      @ctx.strokeStyle = tickColor
      @ctx.stroke()

      @ctx.font = '10pt Arial'
      @ctx.textAlign = 'center'
      @ctx.fillStyle = textColor

      # draw numbers (bottom)
      if (i % majorTickInterval) is 0 # zoomed out
        @ctx.fillText( tick, @toPixels(tick)+@leftPadding, @canvas.height - textSpacing )
      else if (i % majorTickInterval) is 0
        @ctx.fillText( tick, @toPixels(tick)+@leftPadding, @canvas.height - textSpacing )
      else if (i % majorTickInterval) is 0
        @ctx.fillText( tick, @toPixels(tick)+@leftPadding, @canvas.height - textSpacing )

      # axis header
      @ctx.fillText( 'DAYS', textSpacing+10+@leftPadding, @canvas.height - textSpacing )

      # draw ticks (top)
      @ctx.beginPath() 
      @ctx.moveTo( @toPixels(tick)+@leftPadding, 0 )
      if i % majorTickInterval is 0
        @ctx.lineTo( @toPixels(tick)+@leftPadding, 0 + tickMajorLength ) # major tick
      else
        @ctx.lineTo( @toPixels(tick)+@leftPadding, 0 + tickMinorLength ) # minor tick
      @ctx.lineWidth = tickWidth
      @ctx.strokeStyle = tickColor
      @ctx.stroke()

      # top numbers
      if (i % 4) is 0 # zoomed out
        @ctx.fillText( (tick + @originalMin).toFixed(2), @toPixels(tick)+@leftPadding, 0 + textSpacing+10 )
      
  drawYTickMarks: (yMin, yMax) ->
    # generate intervals
    yTicks = []
    yStep = Math.abs(yMin-yMax)/20
    meanTickIndexIsEven = false
    tickIdx = 0

    numStepsUp = Math.ceil (yMax-1.0)/yStep
    numStepsDown = Math.round (1.0-yMin)/yStep

    for stepFactor in [-numStepsDown..numStepsUp]
      tickValue = 1+stepFactor*yStep
      unless tickValue >= yMax or tickValue <=yMin
        if tickValue is 1.0 
          if (tickIdx%2 is 0)
            meanTickIndexIsEven = true
        yTicks.push tickValue
        tickIdx++

    if yStep < 0.001
      textDecimals = 4
    else
      textDecimals = 3

    tickMinorLength = 5
    tickMajorLength = 10
    tickWidth = 1
    tickColor = '#323232' #'rgba(200,20,20,1)' 
    textColor = '#323232'
    textSpacing = 15
    majorTickInterval = 2
    minorTickInterval = 1
    textInterval = 2

    # REQUIRED FOR MEAN NORMALIZATION
    yMean = @mean(@data.y)

    for tick, i in [yTicks...]
      continue if i is 0               # skip first value
      continue if i is yTicks.length-1 # skip last value

      tickPos = @toCanvasYCoord(tick)     # transform to canvas coordinate
      tickPos = -tickPos + @canvas.height # flip y-axis

      # draw axis
      @ctx.font = '10pt Arial'
      @ctx.textAlign = 'left'
      @ctx.fillStyle = textColor
      @ctx.beginPath() 
      @ctx.moveTo( 0, tickPos )

      # make sure 1.00 (mean) tickmark is labeled
      if meanTickIndexIsEven
        if i % majorTickInterval is 0
          @ctx.lineTo( tickMajorLength, tickPos ) # major tick
          @ctx.fillText( tick.toFixed(textDecimals), 0+textSpacing, tickPos+5 )

        else
          @ctx.lineTo( tickMinorLength, tickPos ) # minor tick
      else
        if i % majorTickInterval-1 is 0
          @ctx.lineTo( tickMajorLength, tickPos ) # major tick
          @ctx.fillText( tick.toFixed(textDecimals), 0+textSpacing, tickPos+5 )

        else
          @ctx.lineTo( tickMinorLength, tickPos ) # minor tick

      @ctx.lineWidth = tickWidth
      @ctx.strokeStyle = tickColor
      @ctx.stroke()

  clearCanvas: -> @ctx.clearRect(0,0,@canvas.width, @canvas.height)

  toPixels: (dataPoint, printValue) -> 
    pixel = ( (parseFloat(dataPoint) - parseFloat(@xMin)) / (parseFloat(@xMax) - parseFloat(@xMin)) ) * \
      ( parseFloat(@canvas.width) - parseFloat(@leftPadding) )
    if printValue
      console.log "[xMin,xMax]  = [#{@xMin},#{@xMax}]"
      console.log "canvas.width = #{@canvas.width}"
      console.log "leftPadding  = #{@leftPadding}"
      console.log "dataPoint    = #{dataPoint}"
      console.log "pixel        = #{pixel}"
    return pixel

  toCanvasYCoord: (dataPoint) -> ((parseFloat(dataPoint) - parseFloat(@yMin)) / (parseFloat(@yMax) - parseFloat(@yMin))) * (parseFloat(@canvas.height))
  toDays: (canvasPoint) -> ((parseFloat(canvasPoint) / (parseFloat(@canvas.width)-parseFloat(@leftPadding))) * (parseFloat(@xMax) - parseFloat(@xMin))) + parseFloat(@xMin)
  toDataYCoord: (canvasPoint) -> ((parseFloat(canvasPoint) / parseFloat(@canvas.height)) * (parseFloat(@yMax) - parseFloat(@yMin))) + parseFloat(@yMin)

  addMarkToGraph: (e) =>
    return if @markingDisabled
    e.preventDefault()
    if @marks.markTooCloseToAnother(e, @scale, @originalMin)
      classifier.notify 'Marks may not overlap!'
      @shakeGraph()
      return

    # create new mark
    @mark = new Mark(e, @, @originalMin)
    # return unless @mark.containsPoints()
    @marks.appendElement(@mark)
    @mark.draw(e)
    @mark.onMouseDown(e)

  shakeGraph: ->
    graph = $('#graph-container')
    return if graph.hasClass('shaking')
    graph.addClass('shaking') 
    graph.effect( "shake", {times:4, distance: 2}, 700, =>
        graph.removeClass('shaking')
      ) # eventually remove jquery ui dependency?

class Marks
  constructor: -> @all = []
  appendElement: (mark) -> document.getElementById('marks-container').appendChild(mark.element)
  add: (mark) -> @all.push(mark)

  remove: (mark) ->
    @all.splice(@all.indexOf(mark), 1)
    document.getElementById('marks-container').removeChild(mark.element)

  destroyAll: ->
    mark.element.outerHTML = "" for mark in @all
    @all = []
    document.getElementById('marks-container')

  sortedXCoords: ->
    allXPoints = ([mark.canvasXMin, mark.canvasXMax] for mark in @all)
    [].concat.apply([], allXPoints).sort (a, b) -> a - b
    # or
    # (allXPoints.reduce (a, b) -> a.concat b).sort (a, b) -> a - b

  closestXBelow: (xCoord) -> (@sortedXCoords().filter (i) -> i < xCoord).pop()
  closestXAbove: (xCoord) -> (@sortedXCoords().filter (i) -> i > xCoord).shift()
  toCanvasXPoint: (e) -> e.pageX - e.target.getBoundingClientRect().left - window.scrollX

  markTooCloseToAnother: (e, scale) ->
    mouseLocation = @toCanvasXPoint(e)
    markBelow = Math.abs mouseLocation - @closestXBelow(mouseLocation)
    markAbove = Math.abs mouseLocation - @closestXAbove(mouseLocation)
    # 22 is width of mark plus some room on each side
    markBelow < (10*scale) or markAbove < (10*scale) or mouseLocation in @sortedXCoords()

# -------------------------
#  MARK CLASS
# -------------------------
class Mark
  constructor: (e, @canvasGraph, @originalMin) ->
    @timestamp = (new Date).toUTCString()
    @zoomLevelAtCreation = @canvasGraph.zoomLevel
    @canvas = @canvasGraph.canvas

    @element = document.createElement('div')
    @element.className = "mark"

    bgColor = "#fc4541"

    @element.innerHTML = """
      <div class="top-bar" style="position: relative; width:100%; height: 13px; top 0px; background-color: #{bgColor}; cursor: pointer;">
        <img class="close-icon" src="./images/icons/close-x.svg" style="position: relative; bottom: 4px;">
      </div>
      <div class="left-border" style="position: absolute; top: 0px; left: -1px;width: 2px; height: 100%; background-color: #{bgColor}; padding-bottom: 2px; z-index: 100; cursor: ew-resize;">
        <div class="left-handle" style="position: absolute; left: -5px; width: 12px; height: 12px; background-color: #{bgColor}; top: 50%; border-radius: 3px; color: #b7061e; font-size: 8px; letter-spacing: 1px;">III</div>
      </div>
      <div class="right-border" style="position: absolute; top: 0px; right: -1px; width: 2px; height: 100%; background-color: #{bgColor}; padding-bottom: 2px; z-index: 100; cursor: ew-resize;">
        <div class="right-handle" style="position: absolute; right: -5px; width: 12px; height: 12px; background-color: #{bgColor}; top: 50%; border-radius: 3px; color: #b7061e; font-size: 8px; letter-spacing: 1px;">III</div>
      </div>
    """

    # @element.getElementsByClassName('.left-handle').fadeOut()
    # # @element.find('.right-handle').fadeOut()

    @element.style.left = parseFloat(@toCanvasXPoint(e)) + "px"
    @element.style.position = 'absolute'
    @element.style.top = e.target.offsetTop + "px"
    @element.style.height = (@canvas.height - 2) + 'px'
    @element.style.backgroundColor = 'rgba(252,69,65,.4)'
    @element.style.borderBottom = "2px solid #{bgColor}"
    @element.style.pointerEvents = 'auto'
    @element.style.textAlign = 'center'
    @element.style.cursor = "move"

    @sliderValue = +classifier.el.find('#ui-slider').val()
    @initialLeft = @toCanvasXPoint(e) - (@minWidth()/2)
    @dragging = true

    # create event listeners
    @element.addEventListener 'mousedown', @onMouseDown
    @element.addEventListener 'touchstart', @onMouseDown
    @element.addEventListener 'mouseover', @onMouseOver
    @element.addEventListener 'mouseout', @onMouseOut

  toPixels: (dataPoint) -> ((parseFloat(dataPoint) - parseFloat(@xMin)) / (parseFloat(@xMax) - parseFloat(@xMin))) * (parseFloat(@canvas.width)-parseFloat(@leftPadding))
  minWidth: -> 0.5*(@canvas.width-@canvasGraph.leftPadding)/(@canvasGraph.xMax-@canvasGraph.xMin)
  maxWidth: -> 2.0*(@canvas.width-@canvasGraph.leftPadding)/(@canvasGraph.xMax-@canvasGraph.xMin)
  handleWidth: -> 16 * (@canvasGraph.scale || 1)

  draw: (e) ->

    markLeftX = Math.max @initialLeft + @minWidth() - @maxWidth(),
                         Math.min @initialLeft, @toCanvasXPoint(e)

    markRightX = Math.max @initialLeft + @minWidth(), @toCanvasXPoint(e)

    # no overlapping of marks
    markLeftX = Math.max markLeftX,
                        (@closestXBelow + @handleWidth()/2 || markLeftX),
                        (@canvasGraph.toPixels(@canvasGraph.smallestX))

    markRightX = Math.min markRightX,
                         (@closestXAbove - @handleWidth()/2 || markRightX),
                         (@canvasGraph.toPixels(@canvasGraph.largestX))

    # max and min width on creating / resizing marks
    width = Math.min (Math.max (Math.abs parseFloat(markRightX) - parseFloat(markLeftX)), parseFloat(@minWidth())), parseFloat(@maxWidth())
    # console.log 'WIDTH: ', parseFloat(width), ' (pixels)'
    # console.log 'WIDTH: ', @canvasGraph.toDays(parseFloat(width)), ' (days)'

    @element.style.left = parseFloat(markLeftX) + "px"
    @element.style.width = parseFloat(width) + "px"
    @save( markLeftX, markLeftX+width )

  move: (e) ->
    # console.log 'MOVE!'
    markWidth = parseFloat(@element.style.width)
    
    # no overlapping of marks or moving out of canvas bounds
    leftXPos = Math.max (@toCanvasXPoint(e) - @moveOffset),
                        (@closestXBelow || -@handleWidth()/2) + @handleWidth()/2,
                        @canvasGraph.leftPadding
    leftXPos = Math.min leftXPos,
                        ((@closestXAbove || @canvas.width + @handleWidth()/2) - markWidth) - @handleWidth()/2

    markRightX = leftXPos + markWidth
    @element.style.left = leftXPos + "px"
    @save(leftXPos, markRightX)

  save: (markLeftX, markRightX) ->

    #canvas coords
    @canvasXMin = markLeftX
    @canvasXMax = markRightX

    #data coords
    @dataXMinRel = @canvasGraph.toDays(@canvasXMin-@canvasGraph.leftPadding)
    @dataXMaxRel = @canvasGraph.toDays(@canvasXMax-@canvasGraph.leftPadding)
    @dataXMinGlobal = @dataXMinRel + @originalMin    
    @dataXMaxGlobal = @dataXMaxRel + @originalMin

  onMouseOver: (e) =>
    @element.style.backgroundColor = 'rgba(252,69,65,.6)'
    @element.children[1].children[0].style.visibility = "visible"
    @element.children[2].children[0].style.visibility = "visible"

  onMouseOut: (e) =>
    @element.style.backgroundColor = 'rgba(252,69,65,.4)'
    @element.children[1].children[0].style.visibility = "hidden"
    @element.children[2].children[0].style.visibility = "hidden"

  onMouseDown: (e) =>
    return if @canvasGraph.markingDisabled
    e.preventDefault()
    window.addEventListener 'mousemove', @onMouseMove
    window.addEventListener 'mouseup', @onMouseUp
    window.addEventListener 'touchmove', @onMouseMove
    window.addEventListener 'touchend' , @onTouchEnd

    @element.parentNode.appendChild(@element) #move to end of container for z index

    if e.target.className is "right-border" or e.target.className is "right-handle"
      @initialLeft = @canvasXMin
      @dragging = true
    else if e.target.className is "left-border" or e.target.className is "left-handle"
      @initialLeft = @canvasXMax - @minWidth()
      @dragging = true
    else if e.target.className is "mark"
      @moving = true

    @moveOffset = (@toCanvasXPoint(e) - @canvasXMin)
    @closestXBelow = @canvasGraph.marks.closestXBelow(@canvasXMin)
    @closestXAbove = @canvasGraph.marks.closestXAbove(@canvasXMax)

  onMouseMove: (e) =>
    e.preventDefault()
    @draw(e) if @dragging
    @move(e) if @moving

  onTouchEnd: (e) => # for touch devices
    e.preventDefault()
    window.removeEventListener 'mousemove', @onMouseMove
    window.removeEventListener 'mouseup', @onMouseUp
    window.removeEventListener 'touchmove', @onMouseMove
    window.removeEventListener 'touchend', @onTouchEnd
    
    @canvasGraph.marks.add(@) unless (@ in @canvasGraph.marks.all)
    @canvasGraph.marks.remove(@) if e.target.className is "top-bar" or e.target.className is "close-icon"
    for mark in @canvasGraph.marks.all
      mark.dragging = false
      mark.moving = false

  onMouseUp: (e) =>
    @onTouchEnd(e)
    # ensure points inside mark (otherwise delete)
    unless @containsPoints(@canvasGraph.data.x)
      marks.remove(@)
      classifier.notify 'You\'ve marked a gap (where we have no data about the star). Please ignore those regions.'
      @canvasGraph.shakeGraph()
    $(document).trigger("mark-change")

  containsPoints: (xValues) =>
    for value in xValues
      if value <= @dataXMaxRel and value >= @dataXMinRel
        return true
    return false
    return true # DEBUG

  toCanvasXPoint: (e) -> e.pageX - @canvas.getBoundingClientRect().left - window.scrollX

module?.exports = CanvasGraph: CanvasGraph, Marks: Marks, Mark: Mark
