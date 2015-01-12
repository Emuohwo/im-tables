Event = require '../../event'
CoreView = require '../../core-view'
Options = require '../../options'
Templates = require '../../templates'

# methods we are composing in.
SetsPathNames = require '../../mixins/sets-path-names'

# The data-model object.
SummaryItems = require '../../models/summary-items'
NumericRange = require '../../models/numeric-range'

# The child views of this view.
SummaryHeading = require './summary-heading'
FacetItems = require './items'
FacetVisualisation = require './visualisation'

class FacetTitle extends CoreView

  tagName: 'dt'

  initialize: ->
    super
    @listenForChange @model, @reRender, 'got'
    @listenForChange @state, @reRender, 'open', 'pathName'
  
  template: Templates.template 'facet_title'

module.exports = class FacetView extends CoreView

  className: 'im-facet-view'

  @include SetsPathNames

  # May inherit state, defines a model based on @query and @view
  initialize: ({@query, @view, @noTitle}) ->
    super model: (new SummaryItems {@query, @view})
    @range = new NumericRange
    @listenTo @model, 'change:min change:max', @setLimits
    @state.set(open: Options.get 'Facets.Initally.Open') unless @state.has 'open'
    @listenTo @state, 'change:open', @honourOpenness
    @setPathNames()
    @setLimits()

  setLimits: -> if @model.get 'numeric'
    @range.setLimits @model.pick 'min', 'max'

  # Conditions that must be true by initialisation.

  invariants: ->
    hasQuery: "No query"
    hasAttrView: "The view is not an attribute: #{ @view }"

  hasQuery: -> @query?

  hasAttrView: -> @view?.isAttribute?()

  # Rendering logic. This is a composed view that has no template of its own.

  postRender: ->
    @renderTitle()
    @renderVisualisation()
    @renderItems()
    @honourOpenness()

  renderTitle: ->
    @renderChild 'title', (new SummaryHeading {@model, @state}) unless @noTitle

  # TODO - render the visualisation here.
  renderVisualisation: ->
    @renderChild 'viz', (new FacetVisualisation {@model, @state, @range})

  # TODO - render the values here.
  renderItems: ->
    @renderChild 'facet', (new FacetItems {@model, @state, @range})

  honourOpenness: ->
    isOpen = @state.get 'open'
    wasOpen = @state.previous 'open'
    facet = @$ 'dd.im-facet'

    if isOpen
      facet.slideDown()
      @trigger 'opened', @
    else
      facet.slideUp()
      @trigger 'closed', @

    if wasOpen? and (isOpen isnt wasOpen)
      @trigger 'toggled', @

  # Event definitions and their handlers.

  events: ->
    'click .im-summary-heading': 'toggle'

  toggle: -> @state.toggle 'open'

  close: -> @state.set open: false

  open: -> @state.set open: true

