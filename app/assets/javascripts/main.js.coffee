Turbolinks.enableProgressBar()
$ ->
  #setSizes = ()->
    #height = $(window).height() - $('#nav').outerHeight()
    #width = $(window).width()
    ##$('section', '#dashboard').css {'height': height}

  #$(window).resize $.debounce 100, ->
      #setSizes()

  $(document).on 'page:fetch', ->
    $('#main').addClass('animated fadeOut')

  $(document).on 'page:load', ->
    Analytical.track()

  $(document).on 'page:restore', ->
    Analytical.track()

  $(document).on 'page:change', ->
    #fade/in out on page transition
    $('#main').removeClass('fadeOut').addClass('animated fadeIn')

    #set focus on flash then shift to page title
    $flash = $('#flash-messages')
    if $flash.text().trim().length > 0
      $flash.attr('tabindex', -1).focus()
      $flash.on 'closed.bs.alert', () ->
        $('#page-title').focus()
    #or just put it on the page title
    else
      $('#page-title').focus()

    #allow file input for csv upload
    $('input[type=file]').bootstrapFileInput()

    #remove :visited attributes on */new for screen readers
    $('a.new-link').removeProp('visited')

    #show instructions per metum on description form
    $('#description_metum_id').off().on 'change',  (e) ->
      metum_id = $(@).find(":selected").val()
      $("#metum-instructions-" + metum_id).slideDown().siblings().slideUp()

    #ajax boolean toggle
    $('.boolean-toggle').off().on 'click', (e) ->
      $(@).toggleClass 'fa-check'
          .toggleClass 'fa-times'

    #selectAll
    $('#select-all').click (event) ->
      state =  @checked
      $(':checkbox').each ->
        @checked = state
        return
      return

    #get MCA title
    $canonicals = $('[data-canonical-id]')
    if $canonicals.length > 0
      canonical_ids = []
      $canonicals.each () ->
        id = $(@).data('canonical-id')
        canonical_ids.push(id) if canonical_ids.indexOf(id) == -1
        $(@).text('Loading title...') if $(@).is('span')

      data = {'canonical_ids' :  canonical_ids}
      #console.log data
      $.ajax
        url: '/images/titles'
        type: "POST"
        dataType: "json"
        data: data
        success: (data) ->
          #console.log(data)
          id_titles = data
          $canonicals.each () ->
            id = $(@).data('canonical-id')
            title = id_titles[id]
            md_title = marked(title)
            md_text = $(md_title).text()
            if title
              if $(@).is('span')
                $(@).html(md_title)
              else if $(@).is('img')
                $(@).attr('alt', md_text)
            else
              if $(@).is('span')
                $(@).text('Title unavailable')

        error: (jqXHR, textStatus, errorThrown) ->
          #alert textStatus, errorThrown
          $canonicals.each () ->
            if $(@).is('span')
              $(@).text('Title unavailable')

    #bulk ajax action
    $('.bulk').off().on 'click', (e) ->
      bulk          = $(@).data('bulk') #used for strong params
      url           = $(@).data('url')
      actor         = $(@).data('actor')
      actor_css     = actor.replace(/_/g, '-')
      actor_value   = $(@).data(actor_css)
      selector      = $(@).data('selector')
      selector_name = selector.replace(/_/g, '-')
      selector_css  = '.' + selector_name

      $selections = $('' + selector_css + ":checked")

      sets = []
      for selection in $selections
        set = {}
        set[actor] = actor_value
        set[selector] = $(selection).data(selector_name)
        sets.push set
      data = {}
      data[bulk] = sets

      
      $('#main').addClass('animated fadeOut')
      $.ajax
        url: url
        type: "POST"
        data: data
        success: (data) ->
          Turbolinks.visit(window.location)

        error: (jqXHR, textStatus, errorThrown) ->
          alert textStatus, errorThrown
          $('#main').addClass('animated fadeIn')

