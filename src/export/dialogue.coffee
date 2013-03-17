do ->

  EXPORT_FORMATS = [
      {name: "Spreadsheet (tab separated values)", extension: "tsv", param: "tab"},
      {name: "Spreadsheet (comma separated values)", extension: "csv"},
      {name: "XML", extension: "xml"},
      {name: "JSON", extension: "json"},
  ]

  BIO_FORMATS = [
      {name: "GFF3 (General Feature Format)", extension: "gff3"},
      {name: "UCSC-BED (Browser Extensible Display Format)", extension: "bed"},
      {name: "NCBI compatible FASTA sequence", extension: "fasta"}
  ]

  class ExportDialogue extends Backbone.View

      tagName: 'div'
      className: "modal im-export-dialogue"

      initialize: (query) ->
          @query = query.clone() # Take a snapshot, not a reference.
          @service = query.service
          @requestInfo = new Backbone.Model
            format: EXPORT_FORMATS[0]
            allRows: true
            allCols: true
            start: 0
            compress: "no"
            columnHeaders: true
            galaxy: intermine.options.GalaxyMain

          @state = new Backbone.Model

          @state.on 'change:isPrivate', @onChangePrivacy
          @state.on 'change:url', @onChangeURL
          @state.on 'change:section', @onChangeSection

          @service.whoami (user) =>
            if user.hasPreferences and (myGalaxy = user.preferences['galaxy-url'])
              @requestInfo.set galaxy: myGalaxy

          @service.fetchVersion (v) => @$('.im-ws-v12').remove() if v < 12

          @requestInfo.on "change:galaxy", (m, uri) =>
            input = @$('input.im-galaxy-uri')
            currentVal = input.val()
            input.val(uri) unless currentVal is uri
            @$('.im-galaxy-save-url').attr disabled: uri is intermine.options.GalaxyMain

          @exportedCols = new Backbone.Collection
          @resetExportedColumns()

          @requestInfo.on 'change', @buildPermaLink
          @requestInfo.on 'change:format', @onChangeFormat, @
          @requestInfo.on 'change:format', @updateFormatOptions, @
          @requestInfo.on 'change:start', (m, start) =>
              $elem = @$('.im-first-row')
              newVal = "#{start + 1}"
              if newVal isnt $elem.val()
                  $elem.val newVal
              @$slider?.slider 'option', 'values', [start, m.get('end') - 1 ]
          @requestInfo.on 'change:end', (m, end) =>
              $elem = @$('.im-last-row')
              newVal = "#{end}"
              if newVal isnt $elem.val()
                  $elem.val newVal
              @$slider?.slider 'option', 'values', [m.get('start'), end - 1 ]
          @requestInfo.on "change:format", (m, format) => @$('.im-export-format').val format
          @exportedCols.on 'add remove reset', @initCols
          @exportedCols.on 'add remove change:excluded', =>
            n = @exportedCols.filter( (c) -> not c.get 'excluded').length
            @$('.nav-tabs .im-export-columns').text "#{ n } columns"
          @requestInfo.on 'change:start change:end', =>
            {start, end} = @requestInfo.toJSON()
            @$('.nav-tabs .im-export-rows').text "#{ end - start } rows"

      onChangeFormat: ->
        format = @requestInfo.get 'format'
        tab = @$ '.nav-tabs .im-export-format'
        tab.text "#{ format.extension } format"
        @$('.im-export-formats input').val [ format.extension ]
      
      resetExportedColumns: (e) ->
        e?.stopPropagation()
        e?.preventDefault()
        @$('.im-reset-cols').addClass 'disabled'
        q = @query
        @exportedCols.reset q.views.map (v) -> path: q.getPathInfo v

      readColumnHeaders: (e) ->
        @requestInfo.set columnHeaders: $(e.target).is ':checked'

      readBedChrPrefix: (e) ->
        @requestInfo.set useChrPrefix: $(e.target).is ':checked'

      events: ->
        events =
          'click .im-reset-cols': 'resetExportedColumns'
          'click .im-col-btns': 'toggleColSelection'
          'click .im-row-btns': 'toggleRowSelection'
          'click .close': 'stop'
          'click .im-cancel': 'stop'
          'click a.im-download': 'export'
          'change .im-galaxy-uri': 'changeGalaxyURI'
          'click .im-send-to-galaxy': 'sendToGalaxy'
          'click .im-send-to-genomespace': 'sendToGenomespace'
          'click .im-forget-galaxy': 'forgetGalaxy'
          'change .im-first-row': 'changeStart'
          'change .im-last-row': 'changeEnd'
          'keyup .im-range-limit': 'keyPressOnLimit'
          'submit form': 'dontReallySubmitForm'
          'click .im-perma-link': 'buildPermaLink'
          'click .im-perma-link-share': 'buildSharableLink'
          'click .im-download-file .im-collapser': 'toggleLinkViewer'
          'click .im-download-file .im-copy': 'copyUriToClipboard'
          'click .im-export-destinations > li > a': 'moveToSection'
          'hidden': 'modalHidden'
          'change .im-column-headers': 'readColumnHeaders'
          'change .im-bed-chr-prefix': 'readBedChrPrefix'

        for format in EXPORT_FORMATS.concat(BIO_FORMATS) then do (format) =>
          key = "click .im-format-#{ format.extension }"
          cb = => @requestInfo.set {format}
          events[key] = cb
        for x in ['format', 'columns', 'rows', 'output', 'destination'] then do (x) =>
          key = "click .nav-tabs .im-export-#{ x }"
          cb = (e) =>
            $a = $(e.target)
            if $a.parent().is('.disabled')
              e.preventDefault()
              return false
            $a.data target: @$(".tab-pane.im-export-#{ x }")
            $a.tab('show')
          events[key] = cb
        events

      modalHidden: (e) ->
        # Could have been triggered by tooltip, or popover
        if e? and e.target is @el
          @remove()

      copyUriToClipboard: ->
        window.prompt intermine.messages.actions.CopyToClipBoard, @$('.im-download').attr('href')

      toggleLinkViewer: ->
        @$('.im-download-file .im-perma-link-content').toggleClass 'hide show'
        @$('.im-download-file .im-collapser').toggleClass 'icon-angle-right icon-angle-down'

      moveToSection: (e) ->
        $this = $ e.currentTarget
        $this.tab('show')
        section = $this.data 'section'
        @state.set {section}

      buildSharableLink: (e) ->
          # TODO!!
          @$('.im-perma-link-share-content').text("TODO")

      buildPermaLink: (e) =>
          endpoint = @getExportEndPoint()
          params = @getExportParams()
          isPrivate = intermine.utils.requiresAuthentication @query
          @state.set {isPrivate}
          delete params.token unless isPrivate
          url = endpoint + "?" + $.param(params, true)
          @state.set {url}

      onChangePrivacy: (state, isPrivate) =>
          @$('.im-private-query').toggle isPrivate

      onChangeURL: (state, url) =>
          $a = $('<a>').text(url).attr href: url
          @$('.im-perma-link-content').empty().append($a)
          @$('a.im-download').attr href: url

      onChangeSection:  (m, section) =>
          @$('.im-export-destination-options > div').removeClass 'active'
          @$(".im-#{ section }").addClass 'active'
          @$('.btn-primary.im-download').text intermine.messages.actions[section]

      dontReallySubmitForm: (e) ->
          # Hack to fix bug in struts webapp
          e.preventDefault()
          e.stopPropagation()
          return false # seriously, don't

      forgetGalaxy: (e) ->
        @service
          .whoami()
          .pipe( (user) => console.log(user); user.clearPreference('galaxy-url'))
          .done( () => @requestInfo.set galaxy: intermine.options.GalaxyMain )
        return false

      keyPressOnLimit: (e) ->
        input = $(e.target)
        switch e.keyCode
          when 38 # UP
              input.val 1 + parseInt(input.val(), 10)
          when 40 # DOWN
              input.val parseInt(input.val(), 10) - 1
        input.change()

      changeStart: (e) ->
        if @checkStartAndEnd() # only if valid.
            @requestInfo.set start: parseInt(@$('.im-first-row').val(), 10) - 1 # Start is 0-based, display is 1-based.

      changeEnd: (e) ->
        if @checkStartAndEnd() # only if valid
            @requestInfo.set end: parseInt(@$('.im-last-row').val(), 10)

      DIGITS: /^\s*\d+\s*$/

      checkStartAndEnd: () ->
          start = @$('.im-first-row')
          end = @$('.im-last-row')
          valA = start.val()
          valB = end.val()
          ok = (@DIGITS.test(valA) and parseInt(valA, 10) >= 1) and (@DIGITS.test(valB) and parseInt(valB, 10) <= @count)
          if @DIGITS.test(valA) and @DIGITS.test(valB)
              ok = ok and (parseInt(valA, 10) <= parseInt(valB, 10))
          $('.im-row-selection').toggleClass('error', not ok)
          return ok

      ignore = (e) ->
          e.stopPropagation()
          e.preventDefault()

      sendToGenomespace: (e) ->
          ignore e
          link = 'foo'
          genomeSpaceURL = "https://gsui.genomespace.org/jsui/upload/loadUrlToGenomespace.html?"
          uploadUrl = @state.get 'url'
          fileName = "Results.#{ @requestInfo.get 'format' }"
          qs = $.param {uploadUrl, fileName}

          w = @$('.modal-body').width()
          h = Math.max 400, @$('.modal-body').height()

          console.log w, h

          console.log uploadUrl
          console.log fileName
          console.log qs

          gsFrame = @$('.gs-frame').attr
            src: genomeSpaceURL + qs
            width: w
            height: h

          @$('.btn-primary').addClass 'disabled'

          @$('.carousel').carousel 1
          @$('.carousel').carousel 'pause'

          window.setCallbackOnGSUploadComplete = (savePath) =>
            @$('.carousel').carousel 0
            @$('.carousel').carousel 'pause'
            @$('.btn-primary').removeClass 'disabled'
            @stop()


      sendToGalaxy: (e) ->
          ignore e
          uri = @requestInfo.get 'galaxy'
          @doGalaxy uri
          if @$('.im-galaxy-save-url').is(':checked') and uri isnt intermine.options.GalaxyMain
              @saveGalaxyPreference uri

      saveGalaxyPreference: (uri) -> @query.service.whoami (user) ->
          if user.hasPreferences and user.preferences['galaxy-url'] isnt uri
              user.setPreference 'galaxy-url', uri

      doGalaxy: (galaxy) ->
        query = @query
        console.log "Sending to #{ galaxy }"
        endpoint = @getExportEndPoint()
        format = @requestInfo.get 'format'
        qLists = (c.value for c in @query when c.op is 'IN')
        intermine.utils.getOrganisms query, (orgs) =>
            params =
                tool_id: 'flymine' # name of tool within galaxy that does uploads.
                organism: orgs.join(', ')
                URL: endpoint
                URL_method: "post"
                name: "#{ if orgs.length is 1 then orgs[0] + ' ' else ''}#{ query.root } data"
                data_type: if format is 'tab' then 'tabular' else format
                info: """
                    #{ query.root } data from #{ @service.root }.
                    Uploaded from #{ window.location.toString().replace(/\?.*/, '') }.
                    #{ if qLists.length then ' source: ' + lists.join(', ') else '' }
                    #{ if orgs.length then ' organisms: ' + orgs.join(', ') else '' }
                """
            for k, v of @getExportParams()
                params[k] = v
            intermine.utils.openWindowWithPost "#{ galaxy }/tool_runner", "Upload", params

      changeGalaxyURI: (e) -> @requestInfo.set galaxy: @$('.im-galaxy-uri').val()

      getExportEndPoint: () ->
          format = @requestInfo.get 'format'
          suffix = if format in intermine.Query.BIO_FORMATS then "/#{format}" else ""
          return "#{ @service.root }query/results#{ suffix }"

      # Unnecessary? We could always use this if the url gets too big...
      # openWindowWithPost @getExportEndPoint(), "Export", @getExportParams()
      export: (e) ->
        switch @state.get('section')
          when 'galaxy' then @sendToGalaxy e
          when 'genomespace' then @sendToGenomespace e
          else true # Do the default linky thing

      getExportQuery: () ->
          q = @query.clone()
          f = @requestInfo.get 'format'
          toPath = (col) -> col.get 'path'
          idAttr = (path) -> path.append 'id'
          isIncluded = (col) -> col.get 'included'
          featuresToPaths = (features) -> features.filter(isIncluded).map(_.compose idAttr, toPath)
          columns = switch f
              when 'bed', 'gff3'
                  featuresToPaths @seqFeatures
              when 'fasta'
                  featuresToPaths @fastaFeatures
              else
                  @exportedCols.map(toPath) unless @requestInfo.get('allCols')
          q.select columns if columns?
          q.orderBy([]) if (f in _.pluck BIO_FORMATS, 'extension')
          return q

      getExportParams: () ->
          params = @requestInfo.toJSON()
          params.query = @getExportQuery().toXML()
          params.token = @service.token

          # Clean up params we don't need to send
          delete params.galaxy
          delete params.allRows
          delete params.allCols
          delete params.end
          delete params.compress if params.compress is 'no'

          switch params.format
            when 'gff3', 'fasta' then null # Ignore
            else
              delete params.view

          if @requestInfo.get 'columnHeaders'
              params.columnheaders = "1"
          unless @requestInfo.get 'allRows'
              start = params.start = @requestInfo.get('start')
              end = @requestInfo.get 'end'
              if end isnt @count
                  params.size = end - start
          return params

      getExportURI: () ->
          q = @getExportQuery()
          uri = q.getExportURI @requestInfo.get 'format'
          uri += @getExtraOptions()
          return uri

      getExtraOptions: () ->
          ret = ""
          if @requestInfo.get 'columnHeaders'
              ret += "&columnheaders=1"
          unless @requestInfo.get 'allRows'
              start = @requestInfo.get 'start'
              end = @requestInfo.get 'end'
              ret += "&start=#{ start }"
              if end isnt @count
                  ret += "&size=#{ end - start }"
          ret

      toggleColSelection: (e) -> @requestInfo.set allCols: !@requestInfo.get('allCols'); false

      toggleRowSelection: (e) -> @requestInfo.set allRows: !@requestInfo.get('allRows'); false

      show: -> @$el.modal('show')

      stop: -> @$el.modal('hide')

      remove: () -> # Clean up thoroughly.
        for x in ['requestInfo', 'state', 'exportedCols', 'possibleColumns']
          obj = @[x]
          obj?.close?()
          obj?.destroy?()
          obj?.off()
          delete @[x]
        delete @query
        @$slider?.slider 'destroy'
        delete @$slider
        super()


      isSpreadsheet: ->
        {ColumnHeaders, SpreadsheetOptions} = intermine.messages.actions
        @$('.im-output-options').append  """
          <h2>#{ SpreadsheetOptions }</h2>
          <div>
            <label>
              <span class="span4">#{ ColumnHeaders }</span>
              <input type="checkbox" class="span8 im-column-headers">
            </label>
          </div>
        """
        @$('.im-column-headers').attr checked: !!@requestInfo.get 'columnHeaders'

      isBED: ->
        {BEDOptions, ChrPrefix} = intermine.messages.actions
        chrPref = $ """
          <h2>#{ BEDOptions }</h2>
          <div>
            <label>
              <span class="span4">#{ ChrPrefix }</span>
              <input type="checkbox" class="im-bed-chr-prefix span8">
            </label>
          </div>
        """
        chrPref.appendTo @$ '.im-output-options'
        chrPref.find('input').attr checked: !!@requestInfo.get('useChrPrefix')
        @addSeqFeatureSelector()

      isGFF3: ->
        @addSeqFeatureSelector()
        @addExtraColumnsSelector()

      isFASTA: ->
        @addFastaFeatureSelector()
        @addExtraColumnsSelector()
        @addFastaExtensionInput()

      updateFormatOptions: () ->
        opts = @$('.im-output-options').empty()
        requestInfo = @requestInfo
        format = requestInfo.get 'format'

        if format in BIO_FORMATS
          @$('.im-col-options').hide()
          @$('.im-col-options-bio').show()
          @$('.tab-pane.im-export-rows').removeClass('active')
          @$('.nav-tabs .im-export-rows').parent().removeClass('active').addClass('disabled')
          @requestInfo.set allCols: true
        else
          @$('.im-col-options').show()
          @$('.im-col-options-bio').hide()
          @$('.nav-tabs .im-export-rows').parent().removeClass('disabled')

        if format.extension in ['tsv', 'csv']
          @isSpreadsheet()
        else
          @['is' + format.extension.toUpperCase()]?()

      addFastaExtensionInput: () ->
          opts = @$ '.im-export-options'
          requestInfo = @requestInfo
          l = $ """
              <label>
                  <span class="span4">
                      #{ intermine.messages.actions.FastaExtension }
                  </span>
                  <input type="text" class="span8">
              </label>
          """
          input = l.find('input')
          l.appendTo opts
          @fastaFeatures.on 'change:included', (col, isIncluded) ->
              canHaveExtension = isIncluded and col.get('path').isa('SequenceFeature')
              input.attr disabled: !canHaveExtension
              if canHaveExtension
                  requestInfo.set extension: input.val()
              else
                  requestInfo.unset 'extension'
          input.change (e) ->
              if input.val()?
                  requestInfo.set extension: input.val()
              else
                  requestInfo.unset 'extension'

      addExtraColumnsSelector: () ->
        @extraAttributes = coll = new Backbone.Collection

        coll.on 'change:included', =>
          extras = coll.filter((m) -> m.get('included')).map (m) -> m.get('path').toString()
          @requestInfo.set view: extras

        row = new intermine.actions.ExportColumnOptions
          collection: coll
          message: intermine.messages.actions.ExtraAttributes

        @$('.im-export-options').append row.render().$el

        for path in @query.views
          coll.add path: @query.getPathInfo(path), included: false


      addFastaFeatureSelector: () ->
        @fastaFeatures = coll = new Backbone.Collection
        
        row = new intermine.actions.ExportColumnOptions
          collection: coll
          message: intermine.messages.actions.FastaFeatures
        row.isValidCount = (c) -> c is 1

        @$('.im-export-options').append row.render().$el

        coll.on 'change:included', (questo, incl) =>
          coll.each((quello) -> quello.set(included: false) unless questo is quello) if incl

        included = true
        for node in @query.getViewNodes()
          if (node.isa 'SequenceFeature') or (node.isa 'Protein')
            @fastaFeatures.add path: node, included: included
            included = false

        coll.trigger 'ready'

      addSeqFeatureSelector: ->
        @seqFeatures = coll = new Backbone.Collection

        row = new intermine.actions.ExportColumnOptions
          collection: coll
          message: intermine.messages.actions.IncludedFeatures

        row.isValidCount = (c) -> c > 0

        @$('.im-export-options').append row.render().$el

        for node in @query.getViewNodes() when node.isa 'SequenceFeature'
           coll.add path: node, included: true

        coll.trigger 'ready'

      initColumnOptions: ->
        nodes = ({node} for node in @query.getQueryNodes())
        @possibleColumns = new intermine.columns.models.PossibleColumns nodes,
          exported: @exportedCols

      initCols: () =>
        @$('ul.im-cols li').remove()

        cols = @$ '.im-exported-cols'
        @exportedCols.each (col) =>
          exported = new intermine.columns.views.ExportColumnHeader model: col
          exported.render().$el.appendTo cols

        cols.sortable
            items: 'li'
            axis: 'y'
            placeholder: 'im-resorting-placeholder im-exported-col'
            forcePlaceholderSize: true
            update: (e, ui) =>
              @$('.im-reset-cols').removeClass('disabled')
              silent = true
              @exportedCols.reset cols.find('li').map(-> $(@).data 'model' ).get(), {silent}

        @initColumnOptions()

        maybes = @$ '.im-can-be-exported-cols'
        @maybeView?.remove()
        @maybeView = new intermine.columns.views.PossibleColumns
          collection: @possibleColumns
        maybes.append @maybeView.render().el

      warnOfOuterJoinedCollections: ->
        q = @query
        if _.any(q.joins, (s, p) => (s is 'OUTER') and q.canHaveMultipleValues(p))
          @$('.im-row-selection').append """
            <div class="alert alert-warning">
                <button class="close" data-dismiss="alert">×</button>
                <strong>NB</strong>
                #{ intermine.messages.actions.OuterJoinWarning }
            </div>
          """

      formatToEl = (format) -> """
        <label class="radio">
          <input type="radio" class="im-format-#{ format.extension }"
                 name="im-export-format" value="#{ format.extension }">
          #{ format.name }
        </label>
      """

      initFormats: () ->
        $formats = @$ '.tab-pane.im-export-format .im-export-formats'
        current = @requestInfo.get 'format'

        for format in EXPORT_FORMATS
          $btn = $ formatToEl format
          $formats.append $btn

        @service.fetchModel().done (model) ->
          if intermine.utils.modelIsBio model
            for format in BIO_FORMATS
              $btn = $ formatToEl format
              $formats.append $btn

        $formats.find('input').val [ @requestInfo.get('format').extension ]


      render: () ->

        @$el.append intermine.snippets.actions.DownloadDialogue()
        @$('.modal-footer .btn').tooltip()

        # This really ought to live in events...
        for val in ["no", "gzip", "zip"] then do (val) =>
          @$(".im-#{val}-compression").click (e) =>
            @requestInfo.set compress: val

        @initFormats()
        @initCols()
        @makeSlider()
        @updateFormatOptions()
        @warnOfOuterJoinedCollections()

        @state.set
          section: 'download-file'

        @requestInfo.trigger 'change'
        @requestInfo.trigger 'change:format'

        this

      makeSlider: () ->
        # Unset any previous sliders.
        @$slider?.slider 'destroy'
        @$slider = null
        @query.count (c) =>
          @count = c
          @requestInfo.set end: c
          @$slider = @$('.im-row-range-slider').slider
            range: true,
            min: 0,
            max: c - 1,
            values: [0, c - 1],
            step: 1,
            slide: (e, ui) => @requestInfo.set start: ui.values[0], end: ui.values[1] + 1

  scope "intermine.query.export", {ExportDialogue}
