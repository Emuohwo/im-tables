{Promise} = require 'es6-promise'
_ = require 'underscore'
View = require '../core-view'
Messages = require '../messages'
Templates = require '../templates'

modalTemplate = Templates.template 'modal_base'

class ModalFooter extends View

  RERENDER_EVENT: 'change:error'

  initialize: ({@actionNames}) ->
    super

  getData: -> _.extend {error: null}, @actionNames, super

  template: Templates.template 'modal_footer'

module.exports = class Modal extends View

  className: -> 'modal fade'

  initialize: ->
    super
    # Create a promise and capture its resolution controls.
    @_promise = new Promise((@resolve, @reject) =>)

  resolve: -> throw new Error 'resolved before initialisation'

  reject: -> throw new Error 'rejected before initialisation'

  events: ->
    'click .close': 'hide' # Establish a convention for closing modals.
    'click .modal-footer .btn-cancel': 'hide' # Establish a convention for closing modals.
    'hidden.bs.modal': 'onHidden' # Can be caused by user clicking off the modal.

  promise: -> @_promise

  hide: -> @resolve 'dismiss'

  postRender: ->
    dismissAction = _.result @, 'dismissAction'
    primaryAction = _.result @, 'primaryAction'
    opts =
      model: @state
      actionNames: {dismissAction, primaryAction}
    @renderChildAt 'footer', (new ModalFooter opts), @$ '.modal-footer'
    @show() if @shown # In the case of (unlikely) re-rendering.

  onHidden: (e) ->
    if e? and e.target isnt @el # ignore bubbled events from sub-dialogues.
      return false
    @resolve 'dismiss' # User has dismissed this modal.
    @shown = false
    @remove()

  remove: ->
    return @$el.modal 'hide' if @shown # Allow removal and hiding to go together.
    @reject new Error 'unresolved before removal' # no-op if already resolved or rejected.
    super

  # Override these to provide better text. Can be function or value. You should
  # always override title and primaryAction
  title: -> Messages.getText 'modal.DefaultTitle'
  dismissAction: -> Messages.getText 'modal.Dismiss'
  primaryAction: -> Messages.getText 'modal.OK'
  modalSize: ->

  # Override to provide the modal body. Not required if loading child components.
  body: ->

  # Use this to make use of the default modal structure.
  template: (data) ->
    title = _.result @, 'title'
    body = @body data
    modalSize = _.result @, 'modalSize'
    modalTemplate {title, body, modalSize}

  shown: false

  # Can be called multiple times, and called on re-render.
  # @return [Promise<String>] A promise resolved with the name of an action to take.
  show: ->
    p = @promise()
    p.then (=> @remove()), (=> @remove())

    try
      @$el.modal().modal 'show'
      @trigger 'shown', @shown = true
    catch e
      @reject e

    return p

