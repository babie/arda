module.exports =
class Router
  constructor: (@layoutComponent, @el)->
    @_layout = React.createFactory(@layoutComponent)
    @history = []
    @_mounted = null
    @_locked = false

  isLocked: -> @_locked

  # typeof Context => Thenable<Boolean>
  pushContext: (contextClass, initialProps = {}) -> new Promise (done) =>
    @_lock()
    lastContext = @activeContext
    if lastContext
      lastContext.emit 'paused'

    @activeContext = context = @_createContext contextClass
    @activeContext.emit 'created'
    @activeContext.emit 'started'

    @_mount(context, initialProps).then =>
      @history.push
        name: contextClass.name
        props: initialProps
        context: context
      @_unlock()
      done()

  # () => Thenable<void>
  popContext: -> new Promise (done) =>
    if @history.length <= 0
      throw 'history stack is null'

    @_lock()
    lastContext = @activeContext
    @history.pop()

    # emit disposed in context.dispose
    Promise.resolve(lastContext?.dispose()).then =>
      @activeContext = @history[@history.length-1]?.context
      if @activeContext
        @_mount(@activeContext, @activeContext.props).then =>
          @activeContext.emit 'started'
          @activeContext.emit 'resumed'
          @_unlock()
          done()
      else
        @_unmountAll().then =>
          @_unlock()
          done()

  replaceContext: (contextClass, initialProps = {}) -> new Promise (done) =>
    if @history.length <= 0
      throw 'history stack is null'
    @_lock()
    # emit disposed in context.dispose
    lastContext = @activeContext
    Promise.resolve(lastContext?.dispose()).then =>
      @activeContext = @_createContext(contextClass)
      @activeContext.emit 'created'
      @activeContext.emit 'started'
      @_mount(@activeContext, initialProps).then =>
        @history.pop()
        @history.push
          name: contextClass.name
          props: initialProps
          context: @activeContext
        @_unlock()
        done()

  #  Context * Object  => Thenable<void>
  _mount: (context, initialProps) -> new Promise (done) =>
    context._initTemplatePropsByController(initialProps).then (templateProps) =>
      activeComponent =
        React.withContext {shared: context}, ->
          React.createFactory(context.constructor.component)(templateProps)

      rendered = @_layout {activeComponent}
      @_renderOrUpdate(rendered).then => done()

  #  () => Thenable<void>
  _unmountAll: ->
    rendered = @_layout {activeComponent: null}
    @_renderOrUpdate(rendered)

  #  React.Element => Thenable<void>
  _renderOrUpdate: (rendered) -> new Promise (done) =>
    if @_mounted?
      @_mounted.setProps {activeComponent}
      done()
    else
      # initialize
      if @el
        @_mounted = React.render rendered, @el
      else
        # for test
        @renderedHtml = React.renderToString rendered
      done()

  _createContext: (contextClass) ->
    context = new contextClass
    context.subscribe (eventName, fn) =>
      context.on eventName, fn
    context

  _unlock: -> @_locked = false
  _lock: -> @_locked = true
