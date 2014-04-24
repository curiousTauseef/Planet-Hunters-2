BaseController = require 'zooniverse/controllers/base-controller'
User           = require 'zooniverse/models/user'
Subject        = require 'zooniverse/models/subject'
Classification = require 'zooniverse/models/classification'
MiniCourse     = require '../lib/mini-course'
NoUiSlider     = require "../lib/jquery.nouislider.min"

translate      = require 't7e'
{Tutorial}     = require 'zootorial'
{Step}         = require 'zootorial'
# tutorialSteps  = require '../lib/tutorial-steps'


$ = window.jQuery

{CanvasGraph, Marks, Mark} = require "../lib/canvas-graph"

class Classifier extends BaseController
  className: 'classifier'
  template: require '../views/classifier'

  elements:
    '#toggle-zoom'                      : 'zoomButton'
    '#toggle-fav'                       : 'favButton'
    '#help'                             : 'helpButton'
    '#tutorial'                         : 'tutorialButton'
    'numbers-container'                 : 'numbersContainer'
    '#classify-summary'                 : 'classifySummary'
    '#comments'                         : 'comments'
    '#planet-num'                       : 'planetNum'
    '#alt-comments'                     : 'altComments'
    'button[name="no-transits"]'        : 'noTransitsButton'
    'button[name="finished"]'           : 'finishedButton'
    'button[name="next-subject"]'       : 'nextSubjectButton'
    'button[name="join-convo"]'         : 'joinConvoBtn'
    'button[name="alt-join-convo"]'     : 'altJoinConvoBtn'
    'textarea[name="talk-comment"]'     : 'talkComment'
    'textarea[name="alt-talk-comment"]' : 'altTalkComment'

  events:
    'click button[id="toggle-zoom"]'       : 'onClickZoom'
    'click button[id="toggle-fav"]'        : 'onToggleFav'
    'click button[id="help"]'              : 'onClickHelp'
    'click button[id="tutorial"]'          : 'onClickTutorial'
    'click button[name="no-transits"]'     : 'onClickNoTransits'
    'click button[name="next-subject"]'    : 'onClickNextSubject'
    'click button[name="finished"]'        : 'onClickFinished'
    'slide #ui-slider'                     : 'onChangeScaleSlider'
    'click button[name="join-convo"]'      : 'onClickJoinConvo'
    'click button[name="alt-join-convo"]'  : 'onClickAltJoinConvo'
    'click button[name="submit-talk"]'     : 'onClickSubmitTalk'
    'click button[name="alt-submit-talk"]' : 'onClickSubmitTalkAlt'

  constructor: ->
    super    
    window.classifier = @
    
    # zoom levels [days]: 2x, 10x, 20x
    @zoomRange = 15
    @zoomRanges = []
    @zoomLevel = 0
    isZoomed: false
    ifFaved: false

    User.on 'change', @onUserChange
    Subject.on 'fetch', @onSubjectFetch
    Subject.on 'select', @onSubjectSelect
    @Subject = Subject

    $(document).on 'mark-change', => @updateButtons()
    @marksContainer = @el.find('#marks-container')[0]

    @tutorial = new Tutorial
      firstStep: 'welcome'
      steps:
        welcome: new Step
          header:      translate 'span', 'tutorial.welcome.header'
          details:     translate 'span', 'tutorial.welcome.details'
          attachment: 'center center #graph-container center center'
          next: 'theData1'

        theData1: new Step
          header:      translate 'span', 'tutorial.theData1.header'
          details:     translate 'span', 'tutorial.theData1.details'
          attachment: 'center center #graph-container center center'
          next: 'theData2'


        theData2: new Step
          header:      translate 'span', 'tutorial.theData2.header'
          details:     translate 'span', 'tutorial.theData2.details'
          attachment: 'center center #graph-container center center'
          next: 'theData3'


        theData3: new Step
          header:      translate 'span', 'tutorial.theData3.header'
          details:     translate 'span', 'tutorial.theData3.details'
          attachment: 'center center #graph-container center center'
          next: 'transits1'

        transits1: new Step
          header:      translate 'span', 'tutorial.transits1.header'
          details:     translate 'span', 'tutorial.transits1.details'
          attachment: 'center center #graph-container center center'
          next: 'transits2'

        transits2: new Step
          header:      translate 'span', 'tutorial.transits2.header'
          details:     translate 'span', 'tutorial.transits2.details'
          attachment: 'center center #graph-container center center'
          next: 'findingTransits'

        findingTransits: new Step
          header:      translate 'span', 'tutorial.findingTransits.header'
          details:     translate 'span', 'tutorial.findingTransits.details'
          attachment: 'center center #graph-container center center'
          next: 'markingTransits1'

        markingTransits1: new Step
          header:      translate 'span', 'tutorial.markingTransits1.header'
          details:     translate 'span', 'tutorial.markingTransits1.details'
          attachment: 'center center #graph-container center center'
          next: 'markingTransits2'

        markingTransits2: new Step
          header:      translate 'span', 'tutorial.markingTransits2.header'
          details:     translate 'span', 'tutorial.markingTransits2.details'
          attachment: 'center center #graph-container center center'
          next: 'spotThem'

        spotThem: new Step
          header:      translate 'span', 'tutorial.spotThem.header'
          details:     translate 'span', 'tutorial.spotThem.details'
          attachment: 'center center #graph-container center center'
          next: 'thanks'

        thanks: new Step
          header:      translate 'span', 'tutorial.thanks.header'
          details:     translate 'span', 'tutorial.thanks.details'
          attachment: 'center center #graph-container center center'


    # mini course
    @course = new MiniCourse
    @course.setRate 3

  onUserChange: (e, user) =>
    Subject.next() unless @classification?

  onSubjectFetch: (e, user) =>
    console.log 'onSubjectFetch()'
    @el.find('#loading-screen').show()

  onSubjectSelect: (e, subject) =>
    console.log 'onSubjectSelect()'
    @subject = subject
    @classification = new Classification {subject}
    @loadSubjectData()
    @el.find('#loading-screen').hide()

  loadSubjectData: ->
    @el.find('#ui-slider').attr('disabled',true)
    @el.find(".noUi-handle").fadeOut(150)

    # TODO: use Subject data to choose the right lightcurve
    jsonFile = @subject.location['14-1'] # read actual subject
    # jsonFile = './offline/subject.json' # for debug only

    @canvas?.remove() # kill any previous canvas

    # create new canvas
    @canvas = document.createElement('canvas')
    @canvas.id = 'graph'
    @canvas.width = 1024
    @canvas.height = 420
    
    $.getJSON jsonFile, (data) =>
      @canvasGraph?.marks.destroyAll()  
      @marksContainer.appendChild(@canvas)
      @canvasGraph = new CanvasGraph(@canvas, data)
      @canvasGraph.plotPoints()
      @canvasGraph.enableMarking()
      @drawSliderAxisNums()
      @zoomRanges = [15, 10, 2]
      @magnification = [ '1x (all days)', '10 days', '2 days' ]
      @showZoomMessage(@magnification[@zoomLevel])
      @el.find("#ui-slider").noUiSlider
        start: 0
        range:
          min: @canvasGraph.smallestX
          max: @canvasGraph.largestX - @zoomRange
      @el.find(".noUi-handle").hide()
    @insertMetadata()

  insertMetadata: ->
    metadata = @Subject.current.metadata.magnitudes
    @el.find('#star-id').html( @Subject.current.location['14-1'].split("\/").pop().split(".")[0].concat(" Information") )
    @el.find('#star-type').html(metadata.spec_type)
    @el.find('#magnitude').html(metadata.kepler)
    @el.find('#temperature').html metadata.eff_temp.toString().concat("(K)")
    @el.find('#radius').html metadata.stellar_rad.toString().concat("x Sol")

  onChangeScaleSlider: ->
    val = +@el.find("#ui-slider").val()
    return if @zoomLevel is 0 or @zoomLevel > @zoomRanges.length
    @canvasGraph.plotPoints( val, val + @zoomRanges[@zoomLevel] )

  onClickZoom: ->
    @zoomLevel = @zoomLevel + 1
    if @zoomLevel is 0 or @zoomLevel > @zoomRanges.length-1 # no zoom
      @canvasGraph.zoomOut()
      @el.find("#toggle-zoom").removeClass("zoomed")
      @el.find("#ui-slider").val(0)
      @el.find(".noUi-handle").fadeOut(150)
      @zoomLevel = 0
      @el.find('#ui-slider').attr('disabled',true)
      @el.find("#toggle-zoom").removeClass("allowZoomOut")

    else 
      @el.find('#ui-slider').removeAttr('disabled')
      @canvasGraph.zoomInTo(0, @zoomRanges[@zoomLevel])
      @el.find("#toggle-zoom").addClass("zoomed")
      @el.find("#ui-slider").val(0)

      # rebuild slider
      @el.find("#ui-slider").noUiSlider
        start: +@el.find("#ui-slider").val()
        range:
          'min': @canvasGraph.smallestX,
          'max': @canvasGraph.largestX - @zoomRanges[@zoomLevel]
      , true
      if @zoomLevel is @zoomRanges.length-1
        @el.find("#toggle-zoom").addClass("allowZoomOut")
      else
        @el.find("#toggle-zoom").removeClass("allowZoomOut")
    @showZoomMessage(@magnification[@zoomLevel])
  
  showZoomMessage: (message) =>
    @el.find('#zoom-notification').html(message).fadeIn(100).delay(1000).fadeOut()
    
  notify: (message) =>
    @course.hidePrompt(0) # get the prompt out of the way
    return if @el.find('#notification').hasClass('notifying')
    @el.find('#notification').addClass('notifying')
    @el.find('#notification-message').html(message).fadeIn(100).delay(2000).fadeOut( 400, 'swing', =>
      @el.find('#notification').removeClass('notifying') )

  onToggleFav: ->
    favButton = @el.find("#toggle-fav")[0]
    if @isFaved
      @isFaved = false
      @el.find("#toggle-fav").removeClass("toggled")
    else
      @isFaved = true
      @el.find("#toggle-fav").addClass("toggled")

  onClickHelp: ->
    console.log 'onClickHelp()'
    @el.find('#notification-message').hide() # get any notification out of the way
    # @el.find('#course-prompt').slideDown()
    @course.showPrompt()

  onClickTutorial: ->
    console.log 'onClickTutorial()'
    @notify('Loading tutorial...')
    @tutorial.start()


  updateButtons: ->
    if @canvasGraph.marks.all.length > 0
      @noTransitsButton.hide()
      @finishedButton.show()
    else
      @finishedButton.hide()
      @noTransitsButton.show()

  onClickNoTransits: ->
    @finishSubject()

  onClickFinished: ->
    @finishSubject()

  onClickNextSubject: ->
    @noTransitsButton.show()
    @classifySummary.fadeOut(150)
    @nextSubjectButton.hide()
    @canvasGraph.marks.destroyAll() #clear old marks
    @canvas.outerHTML = ""
    @resetTalkComment @talkComment
    @resetTalkComment @altTalkComment
    # show courses
    if @course.getPref() isnt 'never' and @course.count % @course.rate is 0
      @el.find('#notification-message').hide() # get any notification out of the way
      @course.showPrompt() 
    @el.find('#loading-screen').show()
    @Subject.next()

  finishSubject: ->
    # fake classification counter
    @course.count = @course.count + 1
    console.log 'YOU\'VE MARKED ', @course.count, ' LIGHT CURVES!'
    for mark, i in [@canvasGraph.marks.all...]
      @classification.annotations[i] =
        x_min: mark.dataXMin
        x_max: mark.dataXMax
    console.log JSON.stringify( @classification )
    @classification.send()
    @showSummary()
    # @el.find("#toggle-zoom").removeClass("zoomed")
    @isZoomed = false
    @zoomLevel = 0
    
  showSummary: ->
    @classifySummary.fadeIn(150)
    @nextSubjectButton.show()
    @planetNum.html @canvasGraph.marks.all.length # number of marks
    @noTransitsButton.hide()
    @finishedButton.hide()

  onClickJoinConvo: -> @joinConvoBtn.hide().siblings().show()
  onClickAltJoinConvo: -> @altJoinConvoBtn.hide().siblings().show()

  onClickSubmitTalk: ->
    console.log "SEND THIS TO MAIN TALK DISCUSSION", @talkComment.val()
    @appendComment(@talkComment, @comments)

  onClickSubmitTalkAlt: ->
    console.log "SEND THIS TO ANOTHER TALK DISCUSSION", @altTalkComment.val()
    @appendComment(@altTalkComment, @altComments)

  resetTalkComment: (talkComment) -> talkComment.val("").parent().hide().siblings().show()

  appendComment: (comment, container) ->
    container.append("""
      <div class="formatted-comment">
        <p>#{comment.val()}</p>
        <p>by <strong>#{'currentUser'}</strong> 0 minutes ago</p>
      </div>
    """).animate({ scrollTop: container[0].scrollHeight}, 1000)
    @resetTalkComment comment

  drawSliderAxisNums: ->
    sliderNums = ""
    # for num in [(Math.round @canvasGraph.smallestX + 1)..(Math.round @canvasGraph.largestX)]
    #   sliderNums += if num%2 is 0 then "<span class='slider-num'>#{num}</span>" else "<span class='slider-num'>&#x2022</span>"
    # @el.find("#numbers-container").html sliderNums

module.exports = Classifier
