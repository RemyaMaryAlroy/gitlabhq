class @MergeRequestWidget
  # Initialize MergeRequestWidget behavior
  #
  #   check_enable           - Boolean, whether to check automerge status
  #   merge_check_url - String, URL to use to check automerge status
  #   ci_status_url        - String, URL to use to check CI status
  #

  constructor: (@opts) ->
    @firstCICheck = true
    @getCIStatus()
    notifyPermissions()
    @readyForCICheck = true
    # clear the build poller

  mergeInProgress: (deleteSourceBranch = false)->
    $.ajax
      type: 'GET'
      url: $('.merge-request').data('url')
      success: (data) =>
        if data.state == "merged"
          urlSuffix = if deleteSourceBranch then '?delete_source=true' else ''

          window.location.href = window.location.pathname + urlSuffix
        else if data.merge_error
          $('.mr-widget-body').html("<h4>" + data.merge_error + "</h4>")
        else
          callback = -> merge_request_widget.mergeInProgress(deleteSourceBranch)
          setTimeout(callback, 2000)
      dataType: 'json'

  getMergeStatus: ->
    $.get @opts.merge_check_url, (data) ->
      $('.mr-state-widget').replaceWith(data)

  ciLabelForStatus: (status) ->
    if status == 'success'
      'passed'
    else
      status

  getCIStatus: ->
    _this = @
    @fetchBuildStatusInterval = setInterval ( =>
      return if not @readyForCICheck

      $.getJSON @opts.ci_status_url, (data) =>
        @readyForCICheck = true

        if @firstCICheck
          @firstCICheck = false
          @opts.ci_status = data.status

        if data.status isnt @opts.ci_status
          @showCIState data.status
          if data.coverage
            @showCICoverage data.coverage

          message = @opts.ci_message.replace('{{status}}', @ciLabelForStatus(data.status))
          message = message.replace('{{sha}}', data.sha)
          message = message.replace('{{title}}', data.title)

          notify(
            "Build #{@ciLabelForStatus(data.status)}",
            message,
            @opts.gitlab_icon,
            ->
              @close()
              Turbolinks.visit _this.opts.builds_path
          )

          @opts.ci_status = data.status

      @readyForCICheck = false
    ), 5000

  getCIState: ->
    $('.ci-widget-fetching').show()
    $.getJSON @opts.ci_status_url, (data) =>
      @showCIState data.status
      if data.coverage
        @showCICoverage data.coverage

  showCIState: (state) ->
    $('.ci_widget').hide()
    allowed_states = ["failed", "canceled", "running", "pending", "success", "skipped", "not_found"]
    if state in allowed_states
      $('.ci_widget.ci-' + state).show()
      switch state
        when "failed", "canceled", "not_found"
          @setMergeButtonClass('btn-danger')
        when "running", "pending"
          @setMergeButtonClass('btn-warning')
    else
      $('.ci_widget.ci-error').show()
      @setMergeButtonClass('btn-danger')

  showCICoverage: (coverage) ->
    text = 'Coverage ' + coverage + '%'
    $('.ci_widget:visible .ci-coverage').text(text)

  setMergeButtonClass: (css_class) ->
    $('.accept_merge_request').removeClass("btn-create").addClass(css_class)
