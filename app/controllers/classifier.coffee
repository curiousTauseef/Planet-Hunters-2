BaseController             = require 'zooniverse/controllers/base-controller'
User                       = require 'zooniverse/models/user'
Subject                    = require 'zooniverse/models/subject'
Classification             = require 'zooniverse/models/classification'
MiniCourse                 = require '../lib/mini-course'
NoUiSlider                 = require '../lib/jquery.nouislider.min'
translate                  = require 't7e'
{Tutorial}                 = require 'zootorial'
{Step}                     = require 'zootorial'
initialTutorialSteps       = require '../lib/initial-tutorial-steps'
supplementalTutorialSteps  = require '../lib/supplemental-tutorial-steps'
{CanvasGraph, Marks, Mark} = require "../lib/canvas-graph"
$ = window.jQuery

class Classifier extends BaseController
  className: 'classifier'
  template: require '../views/classifier'

  elements:
    '#zoom-button'                      : 'zoomButton'
    '#toggle-fav'                       : 'favButton'
    '#help'                             : 'helpButton'
    '#tutorial'                         : 'tutorialButton'
    'numbers-container'                 : 'numbersContainer'
    '#classify-summary'                 : 'classifySummary'
    '#comments'                         : 'comments'
    '#planet-num'                       : 'planetNum'
    '#alt-comments'                     : 'altComments'
    'button[name="no-transits"]'        : 'noTransitsButton'
    'button[name="finished-marking"]'   : 'finishedMarkingButton'
    'button[name="finished-feedback"]'  : 'finishedFeedbackButton'
    'button[name="next-subject"]'       : 'nextSubjectButton'
    'button[name="join-convo"]'         : 'joinConvoBtn'
    'button[name="alt-join-convo"]'     : 'altJoinConvoBtn'
    'textarea[name="talk-comment"]'     : 'talkComment'
    'textarea[name="alt-talk-comment"]' : 'altTalkComment'

  events:
    'click button[id="zoom-button"]'         : 'onClickZoom'
    'click button[id="toggle-fav"]'          : 'onToggleFav'
    'click button[id="help"]'                : 'onClickHelp'
    'click button[id="tutorial"]'            : 'onClickTutorial'
    'click button[name="no-transits"]'       : 'onClickNoTransits'
    'click button[name="next-subject"]'      : 'onClickNextSubject'
    'click button[name="finished-marking"]'  : 'onClickFinishedMarking'
    'click button[name="finished-feedback"]' : 'onClickFinishedFeedback'
    'slide #ui-slider'                       : 'onChangeScaleSlider'
    'click button[name="join-convo"]'        : 'onClickJoinConvo'
    'click button[name="alt-join-convo"]'    : 'onClickAltJoinConvo'
    'click button[name="submit-talk"]'       : 'onClickSubmitTalk'
    'click button[name="alt-submit-talk"]'   : 'onClickSubmitTalkAlt'
    'mouseenter #course-yes-container'       : 'onMouseoverCourseYes'
    'mouseleave  #course-yes-container'      : 'onMouseoutCourseYes'
    'change #course-interval'                : 'onChangeCourseInterval'

  constructor: ->
    super    

    # if mobile device detected, go to verify mode
    if window.matchMedia("(min-device-width: 320px)").matches and window.matchMedia("(max-device-width: 480px)").matches
      location.hash = "#/verify"

    window.classifier = @

    @el.find('#star-id').hide()

    # zoom levels [days]: 2x, 10x, 20x
    @zoomRange = 15
    @zoomRanges = []
    @zoomLevel = 0
    isZoomed: false
    ifFaved: false

    # classification counts at which to display supplementary tutorial
    @whenToDisplayTips = [1, 4, 10]

    User.on 'change', @onUserChange
    Subject.on 'fetch', @onSubjectFetch
    Subject.on 'select', @onSubjectSelect
    @Subject = Subject

    $(document).on 'mark-change', => @updateButtons()
    @marksContainer = @el.find('#marks-container')[0]

    @initialTutorial = new Tutorial
      parent: window.classifier.el.children()[0]
      steps: initialTutorialSteps.steps

    @supplementalTutorial = new Tutorial
      parent: window.classifier.el.children()[0]
      steps: supplementalTutorialSteps.steps

    # mini course
    @course = new MiniCourse
    @course.setRate 5
    @el.find('#course-interval-setter').hide()

    @verifyRate = 20

    @recordedClickEvents = []

    @el.find('#no-transits').hide() #prop('disabled',true)
    @el.find('#finished-marking').hide() #prop('disabled',true)
    @el.find('#finished-feedback').hide() #prop('disabled',true)
    console.log '*** DISABLED ***'

  # /////////////////////////////////////////////////
  onMouseoverCourseYes: ->
    # console.log '*** ON ***'
    return unless User.current?
    return if @blockCourseIntervalDisplay
    @blockCourseIntervalDisplay = true
    @el.find('#course-interval-setter').show 400, =>
      @blockCourseIntervalHide = false

  onMouseoutCourseYes: ->
    return unless User.current?
    # console.log '*** OUT ***'
    return if @blockCourseIntervalHide
    @blockCourseIntervalHide = true
    @el.find('#course-interval-setter').hide 400, =>
      @blockCourseIntervalDisplay = false
  # /////////////////////////////////////////////////

  onChangeCourseInterval: ->
    console.log 'VALUE: ', @el.find('#course-interval').val()
    defaultValue = 5
    value = +@el.find('#course-interval').val()

    console.log 'VALUE IS NUMBER: ', (typeof value)

    # validate integer values
    unless (typeof value is 'number') and (value % 1 is 0) and value > 0 and value < 100
      value = defaultValue
      @el.find('#course-interval').val(value)
    else
      console.log 'SETTING VALUE TO: ', value
      @course.setRate value

  onUserChange: (e, user) =>
    console.log 'classify: onUserChange()'
    Subject.next() unless @classification?

  onSubjectFetch: (e, user) =>
    console.log 'classify: onSubjectFetch()'

  onSubjectSelect: (e, subject) =>
    console.log 'classify: onSubjectSelect()'
    @el.find('#loading-screen').show() # TODO: uncomment
    @el.find('#star-id').hide()
    console.log 'onSubjectSelect()'
    @subject = subject
    @classification = new Classification {subject}
    @loadSubjectData()
    @el.find('#loading-screen').hide() # TODO: uncomment

  loadSubjectData: ->
    console.log 'loadSubjectData()'
    @el.find('#ui-slider').attr('disabled',true)
    @el.find(".noUi-handle").fadeOut(150)

    # TODO: use Subject data to choose the right lightcurve
    jsonFile = @subject.selected_light_curve.location
    # jsonFile = 'test_data/test_light_curve.json'
    # jsonFile = 'http://demo.zooniverse.org.s3.amazonaws.com/planet_hunter/new_subjects2/1430893_4.json'
    
    # DEBUG CODE
    # jsonFile = './offline/subject.json' # for debug only
    console.log 'jsonFile: ', jsonFile
    
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
      @zoomRanges = [@canvasGraph.largestX, 10, 2]
      @magnification = [ '1x (all days)', '10 days', '2 days' ]
      @showZoomMessage(@magnification[@zoomLevel])
      @el.find("#ui-slider").noUiSlider
        start: 0
        range:
          min: @canvasGraph.smallestX
          max: @canvasGraph.largestX #- @zoomRange
      @el.find(".noUi-handle").hide()
      
    @insertMetadata()
    @el.find('.do-you-see-a-transit').fadeIn()
    @el.find('#no-transits').fadeIn() #prop('disabled',false)
    @el.find('#finished-marking').fadeIn() #prop('disabled',false)
    @el.find('#finished-feedback').fadeIn() #prop('disabled',false)
    console.log '*** ENABLED ***'

  insertMetadata: ->
    @ra      = @subject.coords[0]
    @dec     = @subject.coords[1]
    ukirtUrl = "http://surveys.roe.ac.uk:8080/wsa/GetImage?ra=" + @ra + "&dec=" + @dec + "&database=wserv4v20101019&frameType=stack&obsType=object&programmeID=10209&mode=show&archive=%20wsa&project=wserv4"
    # console.log 'ukirtUrl: ', ukirtUrl
    metadata = @Subject.current.metadata.magnitudes
    @el.find('#star-id').html( @Subject.current.location['14-1'].split("\/").pop().split(".")[0].concat(" Information") )
    @el.find('#star-type').html(metadata.spec_type)
    @el.find('#magnitude').html(metadata.kepler)
    @el.find('#temperature').html metadata.eff_temp.toString().concat("(K)")
    @el.find('#radius').html metadata.stellar_rad.toString().concat("x Sol")
    @el.find('#ukirt-url').attr("href", ukirtUrl)

  onChangeScaleSlider: ->
    val = +@el.find("#ui-slider").val()
    # if @zoomLevel is 0 or @zoomLevel > @zoomRanges.length
    #   console.log 'RETURNING!!!!!!'
    #   return 
    
    @canvasGraph.plotPoints( val, val + @zoomRanges[@zoomLevel] )
    # # DEBUG CODE
    # console.log 'onChangeScaleSlider(): '
    # console.log '    SLIDER VALUE (val): ', val
    # console.log '    PLOT RANGE          [',val,',',val+@zoomRanges[@zoomLevel],']'
    # console.log '-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-'

  onClickZoom: ->
    console.log 'onClickZoom()'

    # # DO WE NEED THIS?
    # @prevZoomLevel = @zoomLevel

    # console.log '*** PREV ZOOM LEVEL: ',@prevZoomLevel,' ***'
    
    val = +@el.find("#ui-slider").val()

    # increment zoom level
    @zoomLevel = @zoomLevel + 1

    # reset zoom
    if @zoomLevel > 2
      @zoomLevel = 0

    if @zoomLevel is 0
      @zoomReset()
    else 
      # # DO WE NEED THIS?
      # # set slider for current zoom level
      # if val isnt 0 and @prevZoomLevel isnt 2
      #   val = val + 0.5*( @zoomRanges[@prevZoomLevel] - @zoomRanges[@zoomLevel] )
      # if @prevZoomLevel is 2
      #   val = 0
      # @el.find("#ui-slider").val(val) 

      # zoom in to new range
      @canvasGraph.zoomInTo(val, val+@zoomRanges[@zoomLevel])
      console.log 'zoomInTo(', val, ',', val+@zoomRanges[@zoomLevel], ')'

    
      # rebuild slider
      @el.find("#ui-slider").noUiSlider
        start: 0 #+@el.find("#ui-slider").val()
        range:
          'min': @canvasGraph.smallestX,
          'max': @canvasGraph.largestX - @zoomRanges[@zoomLevel]
      , true
      
      # update attributes/properties
      @el.find('#ui-slider').removeAttr('disabled')
      @el.find("#zoom-button").addClass("zoomed")
      if @zoomLevel is 2
        @el.find("#zoom-button").addClass("allowZoomOut")
      else
        @el.find("#zoom-button").removeClass("allowZoomOut")

    # DEBUG CODE        
    # console.log 'onClickZoom(): '
    # console.log 'SLIDER VALUE: ', val
    # console.log 'PLOT RANGE [', val, ',', val+@zoomRanges[@zoomLevel], ']'
    # console.log '******************************************************************************************'

    # # DO WE NEED THIS?
    # @prevZoomMin = 0
    # @prevZoomMax = @zoomRanges[@zoomLevel]

    # console.log 'PREV ZOOM WINDOW: [',@prevZoomMin,',',,']'

    @showZoomMessage(@magnification[@zoomLevel])
    @recordedClickEvents.push { event: 'clickedZoomLevel'+@zoomLevel, timestamp: (new Date).toUTCString() }
  
  zoomReset: =>
    # reset slider value
    @el.find('#ui-slider').val(0)

    # don't need slider when zoomed out
    @el.find('#ui-slider').attr('disabled',true)
    @el.find(".noUi-handle").fadeOut(150)

    @canvasGraph.zoomOut()
    @isZoomed = false
    @zoomLevel = 0

    # update buttons
    @el.find("#zoom-button").removeClass("zoomed")
    @el.find("#zoom-button").removeClass("allowZoomOut")
    @el.find("#toggle-fav").removeClass("toggled")

  showZoomMessage: (message) =>
    console.log 'DISPLAYING ZOOM MESSAGE'
    @el.find('#zoom-notification').html(message).fadeIn(100).delay(1000).fadeOut()
    
  notify: (message) =>
    @course.hidePrompt(0) # get the prompt out of the way
    return if @el.find('#notification').hasClass('notifying')
    @el.find('#notification').addClass('notifying')
    @el.find('#notification-message').html(message).fadeIn(100).delay(2000).fadeOut( 400, 'swing', =>
      @el.find('#notification').removeClass('notifying') )

  onToggleFav: ->
    @classification.favorite = !@classification.favorite
    favButton = @el.find("#toggle-fav")[0]
    if @isFaved
      @isFaved = false
      @el.find("#toggle-fav").removeClass("toggled")
      @notify('Removed from Favorites.')
    else
      @isFaved = true
      @el.find("#toggle-fav").addClass("toggled")
      @notify('Added to Favorites.')

  onClickHelp: ->
    console.log 'onClickHelp()'
    @el.find('#notification-message').hide() # get any notification out of the way
    # @el.find('#course-prompt').slideDown()
    @course.showPrompt()
    
  onClickTutorial: ->
    console.log 'onClickTutorial()'
    @notify('Loading tutorial...')
    @initialTutorial.start()

  updateButtons: ->
    # console.log 'updateButtons()'
    if @canvasGraph.marks.all.length > 0
      @noTransitsButton.hide()
      @finishedMarkingButton.show()
    else
      @finishedMarkingButton.hide()
      @noTransitsButton.show()

  onClickNoTransits: ->
    # console.log 'onClickNoTransits()'
    # giveFeedback() 
    @finishSubject()

  onClickFinishedMarking: ->
    # console.log 'onClickFinishedMarking()'

    # first make sure graph is zoomed out
    @canvasGraph.zoomOut()
    
    @finishedMarkingButton.hide()
    @el.find('#zoom-button').attr('disabled',true)
    @giveFeedback()
  
  giveFeedback: ->
    # console.log 'giveFeedback()'

    @finishedFeedbackButton.show()
    @canvasGraph.disableMarking()
    @canvasGraph.showFakePrevMarks()
    # numMarksGenerated = @canvasGraph.showFakePrevMarks()
    # console.log 'found ', numMarksGenerated, ' previous marks'
    # if numMarksGenerated <= 0 # no marks generated
    #   @notify('Loading summary page...')
    #   @finishedFeedbackButton.hide()
    #   @finishSubject()
    # else
    #   @notify('Here\'s what others have marked...')
    #   @el.find(".mark").fadeOut(1000)
    @notify('<a style="color: rgb(20,100,200)">Here are the locations of known transits and/or simulalations...</a>')
    @el.find(".mark").fadeOut(1000)

  onClickFinishedFeedback: ->
    # console.log 'onClickFinishedFeedback()'
    # @finishedFeedbackButton.hide()

    # keep drawing highlighted points while displaying previous data
    # TODO: fix, kindda cluegy
    $("#graph-container").removeClass('showing-prev-data')    

    @finishSubject()

  onClickNextSubject: ->
    # console.log 'onClickNextSubject()'
    # @noTransitsButton.show()
    @classifySummary.fadeOut(150)
    @nextSubjectButton.hide()
    @canvasGraph.marks.destroyAll() #clear old marks
    @canvas.outerHTML = ""
    @resetTalkComment @talkComment
    @resetTalkComment @altTalkComment
    # show courses

    if @course.count % @verifyRate is 0
      location.hash = "#/verify"

    if @course.getPref() isnt 'never' and @course.count % @course.rate is 0 and @course.coursesAvailable()
      @el.find('#notification-message').hide() # get any notification out of the way
      @course.showPrompt() 


    for classification_count in @whenToDisplayTips
      if @course.count is classification_count
        console.log "*** DISPLAY SUPPLEMENTAL TUTOTIAL # #{classification_count} *** "
        @supplementalTutorial.first = "displayOn_" + classification_count.toString()
        @supplementalTutorial.start()




    @el.find('#loading-screen').show() # TODO: uncomment
    @Subject.next()

  finishSubject: ->
    # console.log 'finishSubject()'
    @finishedFeedbackButton.hide()
    # fake classification counter
    @course.incrementCount()
    console.log 'YOU\'VE MARKED ', @course.count, ' LIGHT CURVES!'
    @classification.annotate recordedClickEvents: [@recordedClickEvents...]

    @classification.annotate
      classification_type: 'light_curve'
      selected_id:          @subject.selected_light_curve._id
      location:             @subject.selected_light_curve.location
    for mark in [@canvasGraph.marks.all...]
      @classification.annotate
        timestamp: mark.timestamp
        zoomLevel: mark.zoomLevelAtCreation
        xMinRelative: mark.dataXMinRel
        xMaxRelative: mark.dataXMaxRel
        xMinGlobal: mark.dataXMinGlobal
        xMaxGlobal: mark.dataXMaxGlobal
    
    # DEBUG CODE
    console.log JSON.stringify( @classification )
    console.log '********************************************'
   
    @classification.send()
    
    # re-enable zoom button (after feedback)
    @el.find('#zoom-button').attr('disabled',false)


    # disable buttons until next lightcurve is loaded
    @el.find('#no-transits').hide() #prop('disabled',true)
    @el.find('#finished-marking').hide() #prop('disabled',true)
    @el.find('#finished-feedback').hide() #prop('disabled',true)
    console.log '*** DISABLED ***'

    # show summary
    @el.find('.do-you-see-a-transit').fadeOut()
    @el.find('#star-id').fadeIn()
    @classifySummary.fadeIn(150)
    @nextSubjectButton.show()
    @planetNum.html @canvasGraph.marks.all.length # number of marks
    # @noTransitsButton.hide()
    @finishedMarkingButton.hide()

    # reset zoom parameters
    @zoomReset()

    @recordedClickEvents = []
    
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

module.exports = Classifier
