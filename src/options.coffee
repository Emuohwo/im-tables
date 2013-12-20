scope "intermine.options",
    INITIAL_SUMMARY_ROWS: 1000,
    NUM_SEPARATOR: ',',
    NUM_CHUNK_SIZE: 3,
    MAX_PIE_SLICES: 15
    ListFreshness: 250 # Number of milliseconds lists requests will be considered fresh for.
    MaxSuggestions: 1000 # Max number of suggestions to fetch and show when editing constraints.
    ListCategorisers: ['organism.name', 'department.company.name']
    PieColors: 'category20'
    CellPreviewTrigger: 'click' # hover
    IndicateOffHostLinks: true
    ExternalLinkIcons:
      "http://some.host.somewhere": "http://some.host.somewhere/logo.png"
    StylePrefix: 'intermine'
    GalaxyMain: "http://main.g2.bx.psu.edu"
    GalaxyCurrent: null
    GalaxyTool: 'flymine'
    GenomeSpaceUpload: "https://gsui.genomespace.org/jsui/upload/loadUrlToGenomespace.html"
    ExternalExportDestinations: # Setting these to false disables them
      Galaxy: true
      Genomespace: true
    ShowId: false
    TableWidgets: ['Pagination', 'PageSizer', 'TableSummary', 'ManagementTools', 'ScrollBar']
    CellCutoff: 100
    CDN: # CDN resources that can be configured.
      server: 'http://cdn.intermine.org'
      resources:
        prettify: [
          '/js/google-code-prettify/latest/prettify.js',
          '/js/google-code-prettify/latest/prettify.css'
        ]
        d3: '/js/d3/3.0.6/d3.v3.min.js'
        'font-awesome': "/css/font-awesome/3.0.2/css/font-awesome.css"
        'filesaver': '/js/filesaver.js/FileSaver.min.js'
    
    D3:
      Transition:
        Easing: 'elastic'
        Duration: 750
    brand:
      "http://www.flymine.org": "FlyMine"
      "http://preview.flymine.org": "FlyMine-Preview"
      "http://www.mousemine.org": "MouseMine (MGI)"
    preview:
      count:
        'http://localhost/intermine-test/service/':
          Department: [ 'employees' ]
          Company: [
            'departments',
            {label: 'employees', query: {select: '*', from: 'Employee', where: {'department.company.id': '{{ID}}'}} }
          ]

        'http://preview.flymine.org/preview/service/':
          Organism: [
            {label: 'Genes', query: {select: '*', from: 'Gene', where: {'organism.id': '{{ID}}'}} }
          ],
          Gene: [
            'pathways', 'proteins', 'publications', 'transcripts', 'homologues'
          ]

do ->

  scope 'intermine',
    setOptions: (opts, ns = '') ->
      ns = if ns is '' or /^\./.test(ns) then 'intermine.options' + ns else ns
      scope ns, opts, true

do ->
  parallel = (promises) -> jQuery.when.apply(jQuery, promises)

  loader = (server) -> (resource) ->
    if /\.css$/.test resource
      link = jQuery('<link type="text/css" rel="stylesheet">')
      link.appendTo('head').attr href: server + resource
      return jQuery.Deferred -> @resolve()
    else
      fetch = jQuery.ajax
        url: server + resource
        cache: true
        dataType: 'script'
      # script loaded, but possibly not executed: hang off a bit
      return fetch.then -> jQuery.Deferred -> _.delay @resolve, 50, true

  scope 'intermine.cdn',

    load: (ident) ->
      {server, resources} = intermine.options.CDN
      conf = resources[ident]
      load = loader server
      if not conf
        jQuery.Deferred -> @reject "No resource is configured for #{ ident }"
      else if _.isArray(conf)
        parallel conf.map load
      else
        load conf


