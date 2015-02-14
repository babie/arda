# {EventEmitter} = require 'events'
EventEmitter = require './event-emitter'

# Context mixin React.Component
module.exports =
class Context extends EventEmitter
  ##### Properties #####
  # static contextType: Object
  # props: Props
  # state: State
  # _component: Component
  ######################

  constructor: (@_component, @props) ->
    super
    subscribers = @constructor.subscribers ? []
    @_onDisposes = []

    @delegateSubscriber (eventName, callback) =>
      if callback?
        return @on eventName, callback
      else
        unless Rx?
          throw new Error 'you need callback as second argument if you don\'t have Rx'
        return Rx.Node.fromEvent @, eventName

  dispose: ->
    Promise.all(@_onDisposes)

  getActiveComponent: -> @_component.refs.root

  delegateSubscriber: (subscribe) ->
    subscribers = @constructor.subscribers ? []
    subscribers.forEach (subscriber) =>
      subscriber @, subscribe

  # (State => State)? => Promise<void>
  update: (stateFn = null) ->
    Promise.resolve(
      if !@state? and @props
        Promise.resolve(@initState(@props))
        .then (@state) => Promise.resolve()
    )
    .then =>
      nextState = stateFn?(@state) ? @state
      # ignore undefined
      if nextState?
        @state = nextState
      
      @expandTemplate(@props, @state)
    .then (templateProps) =>
      @_component.setState
        activeContext: @
        templateProps: templateProps

  # Override
  # Props -> Promise<State>
  initState: (props) -> props

  # Override
  # Props, State -> Promise<TemplateProps>
  expandTemplate: (props, state) -> props

  # Override
  # Register
  render: (templateProps = {}) ->
    component = React.createFactory(@constructor.component)
    component(templateProps)

  # Props => ()
  # Update internal props and state
  _initByProps: (@props) -> new Promise (done) =>
    Promise.resolve(@initState(@props))
    .then (@state) => done()
