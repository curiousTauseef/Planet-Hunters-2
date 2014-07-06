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

    # zoom levels [days]: 2x, 10x, 20x
    @zoomRange = 15
    @zoomRanges = []
    @zoomLevel = 0
    isZoomed: false
    ifFaved: false

    # classification counts at which to display supplementary tutorial
    @whenToDisplayTips = [1, 4, 7]

    User.on 'change', @onUserChange
    Subject.on 'fetch', @onSubjectFetch
    Subject.on 'select', @onSubjectSelect
    @Subject = Subject

    @splitDesignation = null

    $(document).on 'mark-change', => @updateButtons()
    @marksContainer = @el.find('#marks-container')[0]

    @initialTutorial = new Tutorial
      parent: window.classifier.el.children()[0]
      steps: initialTutorialSteps.steps

    @supplementalTutorial = new Tutorial
      parent: window.classifier.el.children()[0]
      steps: supplementalTutorialSteps.steps


    newElement = document.createElement('div')
    newElement.setAttribute 'class', "supplemental-tutorial-option-container"
    newElement.setAttribute 'style', "float: right; padding: 5px;"
    newElement.innerHTML = """
      <input class=\"supplemental-option\" type=\"checkbox\"></input>
      <label>Do not show tips in the fiture.</label>
    """
    @supplementalTutorial.container.getElementsByClassName('zootorial-footer')[0].appendChild(newElement)

    # mini course
    @course = new MiniCourse

    @el.find('#course-interval-setter').hide()

    # @verifyRate = 20

    @recordedClickEvents = []

    @el.find('#no-transits').hide() #prop('disabled',true)
    @el.find('#finished-marking').hide() #prop('disabled',true)
    @el.find('#finished-feedback').hide() #prop('disabled',true)
    
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
    # console.log 'VALUE: ', @el.find('#course-interval').val()
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
    # console.log 'classify: onUserChange()'

    # console.log 'SPLIT DESIGNATION: ', User.current.project.splits.mini_course_sup_tutorial
    if User.current?
      @splitDesignation = User.current.project.splits.mini_course_sup_tutorial
      # @splitDesignation = 'a' # DEBUG CODE

    # HANDLE MINI-COURSE SPLITS
    if @splitDesignation in ['b', 'e']
      console.log 'Setting mini-course interval to 10'
      @course.setRate 10
      $('#course-interval-setter').remove() # destroy custom course interval setter

    else if @splitDesignation in ['c', 'f']
      console.log 'Setting mini-course interval to 25'
      @course.setRate 25
      $('#course-interval-setter').remove() # destroy custom course interval setter

    else if @splitDesignation in ['a', 'd']
      console.log 'Setting mini-course interval to 5'
      @course.setRate 5 # set default
    else
      console.log 'Setting mini-course interval to 5'
      @course.setRate 5 # set default

    # HANDLE SUPPLEMENTAL TUTORIAL SPLITS
    if @splitDesignation in ['a', 'b', 'c', 'g', 'h', 'i']
      @tipsOptIn = true  
    else if @splitDesignation in ['d', 'e', 'f', 'j', 'k', 'l']
      @tipsOptIn = false
    
    # console.log 'BLAH: ', User.current?.preferences.planet_hunter
    if +User.current?.preferences.planet_hunter.count is 0 or not User.current?
      console.log 'First-time user. Loading tutorial...', 
      @onClickTutorial()
    else
      # console.log 'Loading subject.'
      Subject.next() unless @classification?

    # Subject.next() unless @classification?

  onSubjectFetch: (e, user) =>
    console.log 'onSubjectFetch(): '

  onSubjectSelect: (e, subject) =>
    console.log 'onSubjectSelect(): '
    @subject = subject
    @classification = new Classification {subject}
    @loadSubjectData()

  loadSubjectData: () ->
    $('#graph-container').addClass 'loading-lightcurve'
    jsonFile = @subject.selected_light_curve.location
    console.log 'jsonFile: ', jsonFile # DEBUG CODE

    # handle ui elements
    @el.find('#loading-screen').show()
    @el.find('.star-id').hide()
    @el.find('#ui-slider').attr('disabled',true)
    @el.find(".noUi-handle").fadeOut(150)
    
    # remove any previous canvas; create new one
    @canvas?.remove()
    @canvas = document.createElement('canvas')
    @canvas.id = 'graph'
    @canvas.width = 1024
    @canvas.height = 420

    # read json data
    $.getJSON jsonFile, (data) =>
      @canvasGraph?.marks.destroyAll()  
      @marksContainer.appendChild(@canvas)
      @canvasGraph = new CanvasGraph(@canvas, data)
      @canvasGraph.plotPoints()
      @el.find('#loading-screen').hide()
      $('#graph-container').removeClass 'loading-lightcurve'
      @canvasGraph.enableMarking()
      @zoomRanges = [@canvasGraph.largestX, 10, 2]
      @magnification = [ '1x (all days)', '10 days', '2 days' ]
      # update ui elements
      @showZoomMessage(@magnification[@zoomLevel])
      @el.find("#ui-slider").noUiSlider
        start: 0
        range:
          min: @canvasGraph.smallestX
          max: @canvasGraph.largestX #- @zoomRange
      @el.find(".noUi-handle").hide()

    @insertMetadata()
    @el.find('.do-you-see-a-transit').fadeIn()
    @el.find('#no-transits').fadeIn()
    @el.find('#finished-marking').fadeIn()
    @el.find('#finished-feedback').fadeIn()

  insertMetadata: ->
    # ukirt data
    @ra      = @subject.coords[0]
    @dec     = @subject.coords[1]
    ukirtUrl = "http://surveys.roe.ac.uk:8080/wsa/GetImage?ra=" + @ra + "&dec=" + @dec + "&database=wserv4v20101019&frameType=stack&obsType=object&programmeID=10209&mode=show&archive=%20wsa&project=wserv4"
    
    metadata = @Subject.current.metadata
    @el.find('#zooniverse-id').html @Subject.current.zooniverse_id 
    @el.find('#kepler-id').html     metadata.kepler_id
    @el.find('#star-type').html     metadata.spec_type
    @el.find('#magnitude').html     metadata.magnitudes.kepler
    @el.find('#temperature').html   metadata.teff.toString().concat("(K)")
    @el.find('#radius').html        metadata.radius.toString().concat("x Sol")
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
    @el.find('#notification-message').hide() # get any notification out of the way
    @course.showPrompt()
    
  onClickTutorial: ->
    if $('#graph-container').hasClass 'loading-lightcurve'
      @notify 'Please wait until current lightcurve is loaded.'
      return

    # load training subject
    @notify('Loading tutorial...')

    # create tutorial subject
    tutorialSubject = new Subject
      id: 'TUTORIAL_SUBJECT'
      zooniverse_id: 'APH0000009'
      metadata:
        kepler_id: "1431599"
        logg: "4.673"
        magnitudes:
          kepler: "12.320"
        mass: "0.57"
        radius: "0.577"
        teff: "4056"
      selected_light_curve: 
        location: 'https://s3.amazonaws.com/demo.zooniverse.org/planet_hunter/beta_subjects/1873513_15-3.json'
    console.log 'TUTORIAL SUBJECT: ', tutorialSubject

    tutorialSubject.select()

    # do stuff after tutorial complete/aborted
    addEventListener "zootorial-end", =>
      $('.tutorial-annotations.x-axis').removeClass('visible')
      $('.tutorial-annotations.y-axis').removeClass('visible')
      $('.mark').fadeIn()
      # $('.mark').remove()
      # @finishSubject() # loads next subject, among other stuff

    # jsonFile = 'https://s3.amazonaws.com/demo.zooniverse.org/planet_hunter/beta_subjects/1873513_15-3.json'
    # @loadSubjectData(jsonFile)  
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

    @finishSubject() # TODO: remove this line when displaying known lightcurves

    # # DISPLAY KNOWN LIGHTCURVES
    # @canvasGraph.zoomOut() # first make sure graph is zoomed out
    # @finishedMarkingButton.hide()
    # @el.find('#zoom-button').attr('disabled',true)
    # @giveFeedback()
  
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
    # @canvas.outerHTML = ""
    @resetTalkComment @talkComment
    @resetTalkComment @altTalkComment
    # show courses

    if @course.count % @verifyRate is 0
      location.hash = "#/verify"

    if @course.getPref() isnt 'never' and @course.count % @course.rate is 0 and @course.coursesAvailable()
      @el.find('#notification-message').hide() # get any notification out of the way
      @course.showPrompt() 

    # display supplemental tutorial
    for classification_count in @whenToDisplayTips
      if @course.count is classification_count
        console.log "*** DISPLAY SUPPLEMENTAL TUTOTIAL # #{classification_count} *** "
        @supplementalTutorial.first = "displayOn_" + classification_count.toString()
        @supplementalTutorial.start()
        console.log 'supplementalTutorial.el: ', @supplementalTutorial.el
        # @supplementalTutorial.el.
        
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

    # show summary
    @el.find('.do-you-see-a-transit').fadeOut()
    @el.find('.star-id').fadeIn()
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
