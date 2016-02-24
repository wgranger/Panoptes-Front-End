React = require 'react'
SubjectViewer = require '../components/subject-viewer'
SVGImage = require '../components/svg-image'
Draggable = require '../lib/draggable'
drawingTools = require './drawing-tools'
tasks = require './tasks'
Tooltip = require '../components/tooltip'
seenThisSession = require '../lib/seen-this-session'
getSubjectLocation = require '../lib/get-subject-location'

module.exports = React.createClass
  displayName: 'FrameAnnotator'

  getDefaultProps: ->
    user: null
    project: null
    subject: null
    workflow: null
    classification: null
    annotation: null
    onLoad: Function.prototype
    frame: 0
    onChange: Function.prototype

  getInitialState: ->
    naturalWidth: @props.naturalWidth
    naturalHeight: @props.naturalHeight
    naturalX: 0,
    naturalY: 0
    showWarning: false
    sizeRect: null
    alreadySeen: false
    showWarning: false

  componentDidMount: ->
    addEventListener 'resize', @updateSize
    @updateSize()
    @setState alreadySeen: @props.subject.already_seen or seenThisSession.check @props.workflow, @props.subject

  componentDidUpdate: (prevProps, prevState)->
    # If size of the frame image has changed, update our sizing information (used for scaling/translating annotations)
    if @props.naturalWidth isnt prevProps.naturalWidth or @props.naturalHeight isnt prevProps.naturalHeight
      setTimeout =>
        @updateSize()

  componentWillUnmount: ->
    removeEventListener 'resize', @updateSize

  componentWillReceiveProps: (nextProps) ->
    if nextProps.annotation isnt @props.annotation
      @handleAnnotationChange @props.annotation, nextProps.annotation
    @setState
      naturalWidth: nextProps.naturalWidth
      naturalHeight: nextProps.naturalHeight


  handleAnnotationChange: (oldAnnotation, currentAnnotation) ->
    if oldAnnotation?
      # console.log 'Old annotation was', oldAnnotation
      lastTask = @props.workflow.tasks[oldAnnotation.task]
      LastTaskComponent = tasks[lastTask.type]
      if LastTaskComponent.onLeaveAnnotation?
        LastTaskComponent.onLeaveAnnotation lastTask, oldAnnotation
    # if currentAnnotation?
    #   console.log 'Annotation is now', currentAnnotation
    setTimeout => # Wait a tick for the annotation to load.
      @updateSize()

  updateSize: ->
    clientRect = @refs.sizeRect?.getBoundingClientRect() # Read only
    {left, right, top, bottom, width, height} = clientRect
    left += pageXOffset
    right += pageXOffset
    top += pageYOffset
    bottom += pageYOffset
    @setState sizeRect: {left, right, top, bottom, width, height}

  getScale: ->
    horizontal = @state.sizeRect?.width / @props.naturalWidth || 0
    vertical = @state.sizeRect?.height / @props.naturalHeight || 0
    {horizontal, vertical}

  getEventOffset: (e) ->
    scale = @getScale()
    # console?.log 'Subject scale is', JSON.stringify scale
    x = (e.pageX - @state.sizeRect?.left) / scale.horizontal || 0
    y = (e.pageY - @state.sizeRect?.top) / scale.vertical || 0
    {x, y}

  toggleWarning: ->
    @setState showWarning: not @state.showWarning

  zoom: (change) ->
    newNaturalWidth = @state.naturalWidth * change;
    newNaturalHeight = @state.naturalHeight * change;
    
    newNaturalX = @state.naturalX - (newNaturalWidth - @state.naturalWidth)/2;
    newNaturalY = @state.naturalY - (newNaturalHeight - @state.naturalHeight)/2;
    
    @setState
      naturalWidth: newNaturalWidth, 
      naturalHeight: newNaturalHeight,
      naturalX: newNaturalX,
      naturalY:newNaturalY

  zoomReset: ->
    @setState
      naturalWidth: @props.naturalWidth, 
      naturalHeight: @props.naturalHeight,
      naturalX: 0,
      naturalY: 0

  panHorizontal:(direction) ->
    return if this.state.naturalX == 0 || this.state.naturalY == 0   
    @setState
      naturalX: @state.naturalX * direction

  panVertical:(direction)->
    @setState
      naturalY: @state.naturalY * direction

  render: ->    
    taskDescription = @props.workflow.tasks[@props.annotation?.task]
    TaskComponent = tasks[taskDescription?.type]
    {type, format, src} = getSubjectLocation @props.subject, @props.frame
    
    createdViewBox = "#{@state.naturalX} #{@state.naturalY} #{@state.naturalWidth} #{@state.naturalHeight}"
    
    svgStyle = {}
    if type is 'image' and not @props.loading
      # Images are rendered again within the SVG itself.
      # When cropped right next to the edge of the image,
      # the original tag can show through, so fill the SVG to cover it.
      svgStyle.background = 'black'

    svgProps = {}

    if TaskComponent?
      {BeforeSubject, InsideSubject, AfterSubject} = TaskComponent

    hookProps =
      taskTypes: tasks
      workflow: @props.workflow
      task: taskDescription
      classification: @props.classification
      annotation: @props.annotation
      frame: @props.frame
      scale: @getScale()
      naturalWidth: @props.naturalWidth
      naturalHeight: @props.naturalHeight
      containerRect: @state.sizeRect
      getEventOffset: this.getEventOffset
      onChange: @props.onChange

    for task, Component of tasks when Component.getSVGProps?
      for key, value of Component.getSVGProps hookProps
        svgProps[key] = value

    <div className="frame-annotator">
      <div className="subject-area">
        {if BeforeSubject?
          <BeforeSubject {...hookProps} />}

        <svg style=svgStyle viewBox={createdViewBox} {...svgProps}>
          <rect ref="sizeRect" width={@props.naturalWidth} height={@props.naturalHeight} fill="rgba(0, 0, 0, 0.01)" fillOpacity="0.01" stroke="none" />

          {if type is 'image'
            <SVGImage src={src} width={@props.naturalWidth} height={@props.naturalHeight} />}

          {if InsideSubject?
            <InsideSubject {...hookProps} />}

          {for anyTaskName, {PersistInsideSubject} of tasks when PersistInsideSubject?
            <PersistInsideSubject key={anyTaskName} {...hookProps} />}
        </svg>
        {@props.children}
        <span>
          <button className={ "fa fa-arrow-circle-left" + if @state.naturalHeight == @props.naturalHeight then " disabled" else "" } onClick={ @panHorizontal.bind(this, .7) }> </button>
          <button className={ "fa fa-arrow-circle-up" + if @state.naturalHeight == @props.naturalHeight then " disabled" else "" } onClick={@panVertical.bind(this, .7)}> </button>
          <button className={ "fa fa-arrow-circle-down" + if @state.naturalWidth == @props.naturalWidth then " disabled" else ""} onClick={@panVertical.bind(this, 1.3)}> </button>
          <button className={ "fa fa-arrow-circle-right" + if @state.naturalX == 0 then " disabled" else "" } onClick={@panHorizontal.bind(this, 1.3)}> </button>
          <button className="zoom-out fa fa-minus-circle" onClick={ @zoom.bind(this, 1.1) }></button>
          <button className="zoom-in fa fa-plus-circle" onClick={ @zoom.bind(this,.9) } ></button>
          <button className="reset" onClick={ this.zoomReset } >Reset</button>
        </span>
        {if @state.alreadySeen
          <button type="button" className="warning-banner" onClick={@toggleWarning}>
            Already seen!
            {if @state.showWarning
              <Tooltip attachment="top left" targetAttachment="middle right">
                <p>Our records show that you’ve already seen this image. We might have run out of data for you in this workflow!</p>
                <p>Try choosing a different workflow or contributing to a different project.</p>
              </Tooltip>}
          </button>

        else if @props.subject.retired
          <button type="button" className="warning-banner" onClick={@toggleWarning}>
            Finished!
            {if @state.showWarning
              <Tooltip attachment="top left" targetAttachment="middle right">
                <p>This subject already has enough classifications, so yours won’t be used in its analysis!</p>
                <p>If you’re looking to help, try choosing a different workflow or contributing to a different project.</p>
              </Tooltip>}
          </button>}

        {if AfterSubject?
          <AfterSubject {...hookProps} />}
      </div>
    </div>
