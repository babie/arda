EventEmitter = require './event-emitter'
module.exports =
class Router extends EventEmitter
  # React.Class * ?HTMLElement => Router
  constructor: (layoutComponent, @el)->
    @_locked = false
    @_disposers = []
    @history = []

    if @el
      Layout = React.createFactory(layoutComponent)
      @_rootComponent = React.render Layout(), @el
      @_rootComponent.isRoot = true

  # () => boolean
  isLocked: -> @_locked

  dispose: ->
    Promise.all @_disposers.map (disposer) => do disposer
    .then => new Promsie (done) =>
      do popUntilBlank = =>
        if @history.length > 0
          @popContext().then => popUntilBlank()
        else
          done()
    .then =>
      @diposed = true
      @_lock = true
      delete @history
      delete @_disposers
      @removeAllListeners()
      Object.freeze(@)
      if @el?
        React.unmountComponentAtNode(@el)
      @emit 'router:disposed'

  pushContextAndWaitForBack: (contextClass, initialProps = {}) ->
    new Promise (done) =>
      @pushContext(contextClass, initialProps)
      .then (context) =>
        context.on 'context:disposed', done

  # typeof Context => Thenable<Boolean>
  pushContext: (contextClass, initialProps = {}) ->
    @_lock()

    # check
    if lastContext = @activeContext
      lastContext.emit 'context:paused'
      lastContext.lifecycle = 'paused'

    @activeContext = new contextClass @_rootComponent, initialProps
    @_mountToParent(@activeContext, initialProps)
    .then =>
      @history.push
        name: contextClass.name
        props: initialProps
        context: @activeContext
      @_unlock()
      @activeContext.emit 'context:created'
      @activeContext.emit 'context:started'
      @activeContext.lifecycle = 'active'
      @emit 'router:pushed', @activeContext
    .then =>
      @activeContext

  # () => Thenable<void>
  popContext: ->
    if @history.length <= 0
      throw 'history stack is null'

    @_lock()
    @history.pop()

    # emit disposed in context.dispose
    Promise.resolve(
      if lastContext = @activeContext
        @_disposeContext(lastContext)
    )
    .then =>
      @activeContext = @history[@history.length-1]?.context
      if @activeContext?
        @_mountToParent(@activeContext, @activeContext.props, true)
      else
        @_unmountAll()
    .then =>
      if @activeContext
        @activeContext.emit 'context:started'
        @activeContext.emit 'context:resumed'
        @activeContext.lifecycle = 'active'
        @emit 'router:popped', @activeContext
      else
        @emit 'router:blank'
      @_unlock()
    .then =>
      @activeContext

  # () => Thenable<Context>
  replaceContext: (contextClass, initialProps = {}) ->
    if @history.length <= 0
      throw 'history stack is null'
    @_lock()

    lastContext = @activeContext
    Promise.resolve(
      if lastContext then @_disposeContext(lastContext) else null
    )
    .then =>
      @activeContext = new contextClass @_rootComponent, initialProps
      @activeContext.emit 'context:created'
      @activeContext.emit 'context:started'
      @activeContext.lifecycle = 'active'
      @_mountToParent(@activeContext, initialProps)
    .then =>
      @history.pop()
      @history.push
        name: contextClass.name
        props: initialProps
        context: @activeContext
      @_unlock()
      @emit 'router:replaced', @activeContext

    .then =>
      @activeContext

  #  Context * Object  => Thenable<void>
  _mountToParent: (context, initialProps, reuseState = false) ->
    @_initContextWithExpanding(context, initialProps, reuseState)
    .then (templateProps) =>
      @_outputByEnv(context, templateProps)

  #  () => Thenable<void>
  _unmountAll: ->
    @_outputByEnv(null)

  #  React.Element => Thenable<void>
  _outputByEnv: (activeContext, props) ->
    if @el?
      @_outputToDOM(activeContext, props)
    else
      @_outputToRouterInnerHTML(activeContext, props)

  _outputToDOM: (activeContext, props) ->
    @_rootComponent.setState
      # activeContext: activeContext?.render(props)
      activeContext: activeContext
      templateProps: props

  # For test dry run
  _outputToRouterInnerHTML: (activeContext, templateProps) ->
    if activeContext
      rendered = React.createFactory(activeContext.constructor.component)(templateProps)
      @innerHTML = React.renderToString rendered
    else
      @innerHTML = ''

  _unlock: -> @_locked = false

  _lock: -> @_locked = true

  _disposeContext: (context) ->
    delete context.props
    delete context.state
    context.emit 'context:disposed'
    context.lifecycle = 'disposed'
    context.removeAllListeners?()
    context.dispose()
    context.disposed = true
    Object.freeze(context)

  _initContextWithExpanding: (context, props, reuseState = false) ->
    if context.state? and reuseState
      context.expandComponentProps(context.props, context.state)
    else
      context._initByProps(props)
      .then => context.expandComponentProps(context.props, context.state)
