# This script contains code from 4chan X (https://github.com/MayhemYDG/4chan-x)
# @license: https://github.com/MayhemYDG/4chan-x/blob/v3/LICENSE
Set = {}
d   = document
g   =
  NAMESPACE: 'NameSync.'
  VERSION:   '<%= version %>'
  include:   ['b', 'q', 'soc']
  threads:   []

$$ = (selector, root = d.body) ->
  root.querySelectorAll selector
$ = (selector, root = d.body) ->
  root.querySelector selector
$.session = {}
$.local   = {}

$.el = (tag, properties) ->
  el = d.createElement tag
  $.extend el, properties if properties
  el
$.tn = (text) ->
  d.createTextNode text
$.id = (id) ->
  d.getElementById id
$.event = (type, detail) ->
  d.dispatchEvent new CustomEvent type, detail
$.on = (el, type, handler) ->
  el.addEventListener type, handler, false
$.off = (el, type, handler) ->
  el.removeEventListener type, handler, false
$.addClass = (el, className) ->
  el.classList.add className
$.add = (parent, children) ->
  parent.appendChild $.nodes children
$.rm = (el) ->
  el.parentNode.removeChild el
$.prepend = (parent, children) ->
  parent.insertBefore $.nodes(children), parent.firstChild
$.after = (root, el) ->
  root.parentNode.insertBefore $.nodes(el), root.nextSibling
$.before = (root, el) ->
  root.parentNode.insertBefore $.nodes(el), root
$.nodes = (nodes) ->
  unless nodes instanceof Array
    return nodes
  frag = d.createDocumentFragment()
  for node in nodes
    frag.appendChild node
  frag
$.ajax = (file, type, data, callbacks) ->
  r = new XMLHttpRequest()
  r.overrideMimeType 'application/json' if file is 'qp'
  url = "<%= meta.page %>namesync/#{file}.php"
  url += "?#{data}" if type is 'GET'
  r.open type, url, true
  r.setRequestHeader 'X-Requested-With', 'NameSync<%= version %>'
  r.setRequestHeader 'If-Modified-Since', Sync.lastModified if file is 'qp'
  r.setRequestHeader 'Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8' if type is 'POST'
  $.extend r, callbacks
  r.withCredentials = true
  r.send data
  r
$.extend = (object, properties) ->
  for key, val of properties
    object[key] = val
  return
$.local.get = (name) ->
  localStorage.getItem "#{g.NAMESPACE}#{name}"
$.local.set = (name, value) ->
  localStorage.setItem "#{g.NAMESPACE}#{name}", value
$.session.get = (name) ->
  sessionStorage.getItem "#{name}"
$.session.set = (name, value) ->
  sessionStorage.setItem "#{name}", value

CSS =
  init: ->
    css = """
    .section-name-sync input[type='text'] {
      border: 1px solid #CCC;
      width: 148px;
      padding: 2px;
    }
    .section-name-sync input[type='button'] {
      padding: 3px;
      margin-bottom: 6px;
    }
    .section-name-sync p {
      margin: 0 0 8px 0;
    }
    .section-name-sync ul {
      list-style: none;
      margin: 0;
      padding: 8px;
    }
    .section-name-sync label {
      text-decoration: underline;
    }
    #bgimage {
      bottom: 0px;
      right: 0px;
      position: absolute;
    }
    """
    if Set['Hide IDs']
      css += """
    .posteruid {
      display: none;
    }
    """
    if Set['Filter']
      css += """
    .sync-filtered {
      display: none !important;
    }
    """
    $.add d.body, $.el 'style',
      textContent: css

Filter =
  init: ->
    @names     = $.local.get 'FilterNames'
    @tripcodes = $.local.get 'FilterTripcodes'
    @emails    = $.local.get 'FilterEmails'
    @subjects  = $.local.get 'FilterSubjects'

Main =
  init: ->
    $.off d, '4chanXInitFinished', Main.init
    path = location.pathname.slice(1).split '/'
    return if path[1] is 'catalog'
    g.board = path[0]
    return unless g.board in g.include
    for thread in $$ '.thread'
      g.threads.push thread.id[1..]

    Settings.init()
    if Set['Filter']
      Filter.init()
    Names.init()
    CSS.init()
    Menus.init()
    if Set["Sync on /#{g.board}/"]
      Sync.init()
    <% if (type !== 'crx') { %>
    if Set['Automatic Updates']
      Updater.init()
    <% } %>

Menus =
  uid: null
  init: ->
    $.event 'AddMenuEntry',
      detail:
        type: 'header'
        el: @makeSubEntry '4chan X Name Sync Settings', ->
          $.event 'OpenSettings',
          detail: 'Name Sync'
        order: 112
    subEntries = []
    subEntries.push
      el: @makeSubEntry 'Change', ->
        Names.change Menus.uid
        $.event 'CloseMenu'
    subEntries.push
      el: @makeSubEntry 'Reset', ->
        Names.reset Menus.uid
        $.event 'CloseMenu'
      open: ->
        Names.blockedIDs[Menus.uid] is true
    $.event 'AddMenuEntry',
      detail:
        type: 'post'
        el: $.el 'div',
          href: 'javascript:;'
          textContent: 'Name'
        open: (post) ->
          Menus.uid = post.info.uniqueID
          !/Heaven/.test Menus.uid
        subEntries: subEntries
  makeSubEntry: (text, click) ->
    a = $.el 'a',
      href: 'javascript:;'
      textContent: text
    $.on a, 'click', click
    a

Names =
  nameByPost: {}
  init: ->
    @load()
    $.event 'AddCallback',
      detail:
        type: 'Post'
        callback:
          name: '4chan X Name Sync'
          cb: Names.cb
    @updateAllPosts()
  cb: ->
    Names.updatePost @nodes.post if g.board is @board.ID
  change: (id) ->
    name = prompt 'What would you like this poster to be named?', 'Anonymous'
    if name and name.trim() isnt ''
      @nameByID[id] =
        n: name
      @blockedIDs[id] = true
      @updateAllPosts()
  reset: (id) ->
    @nameByID[id] =
      n: 'Anonymous'
    @blockedIDs[id] = false
    @updateAllPosts()
  clear: ->
    $('#namesClear').disabled = true
    Names.nameByID   = {}
    Names.nameByPost = {}
    Names.blockedIDs = {}
    Names.store()
    $('#namesClear').value = 'Cleared'
  load: ->
    stored = $.session.get "#{g.board}-cached"
    @nameByID = if stored then JSON.parse stored else {}
    stored = $.session.get "#{g.board}-blocked"
    @blockedIDs = if stored then JSON.parse stored else {}
  store: ->
    $.session.set "#{g.board}-cached",  JSON.stringify @nameByID
    $.session.set "#{g.board}-blocked", JSON.stringify @blockedIDs
  updateAllPosts: ->
    @updatePost post for post in $$ '.thread .post'
    @store()
  updatePost: (post) ->
    idspan = $ '.hand', post
    return if idspan is null
    id = idspan.textContent
    return if /^##/.test id
    postnum     = $('a[title="Quote this post"]', post).textContent
    oinfo       = Names.nameByPost[postnum]
    linfo       = Names.nameByID[id]
    if oinfo and !Names.blockedIDs[id]
      name      = oinfo.n
      tripcode  = oinfo.t
      if !/Heaven/.test id
        Names.nameByID[id] =
          n: name
          t: tripcode
      email   = oinfo.e
      subject = oinfo.s
    else if linfo
      name     = linfo.n
      tripcode = linfo.t
    else
      return

    namespan          = $ '.desktop .name',       post
    tripspan          = $ '.desktop .postertrip', post
    subjectspan       = $ '.desktop .subject',    post
    subjectspantext   = subjectspan.textContent

    if namespan.textContent isnt name
      namespan.textContent = name
    if subject
      if subjectspantext isnt subject
        subjectspan.textContent = subject
    else
      if subjectspantext isnt ''
        subjectspan.textContent = ''
    if email
      emailspan = $ '.desktop .useremail', post
      if emailspan is null
        nameblockspan = $ '.desktop .nameBlock', post
        emailspan = $.el 'a',
          className: 'useremail'
        $.before namespan, emailspan
      $.add emailspan, namespan
      if tripspan?
        $.after namespan, $.tn ' '
        $.add emailspan, tripspan
      emailspan.href = "mailto:#{email}"
    if tripcode
      if tripspan is null
        tripspan = $.el 'span',
          className: 'postertrip'
        $.after namespan, [$.tn ' '; tripspan]
      if tripspan.textContent isnt tripcode
        tripspan.textContent = tripcode
    else if tripspan
      $.rm tripspan.previousSibling
      $.rm tripspan

    if Set['Filter']
      if Filter.names and RegExp(Filter.names).test name
        return $.addClass post.parentNode, 'sync-filtered'
      if Filter.tripcodes and tripcode and RegExp(Filter.tripcodes).test tripcode
        return $.addClass post.parentNode, 'sync-filtered'
      if oinfo
        if Filter.subjects and subject and RegExp(Filter.subjects).test subject
          return $.addClass post.parentNode, 'sync-filtered'
        if Filter.emails and email and RegExp(Filter.emails).test email
          $.addClass post.parentNode, 'sync-filtered'

Settings =
  main:
    'Sync on /b/':       [true,  'Enable sync on /b/.']
    'Sync on /q/':       [true,  'Enable sync on /q/.']
    'Sync on /soc/':     [true,  'Enable sync on /soc/.']
    'Read-only Mode':    [false, 'Share none of your fields.']
    'Hide Sage':         [false, 'Share none of your fields when sage is in the email field.']
    'Hide IDs':          [false, 'Hide Unique IDs next to names.']
    'Do Not Track':      [false, 'Opt out of name tracking by third party websites.']
    'Persona Fields':    [false, 'Share persona fields instead of the 4chan X quick reply fields.']
    'Filter':            [false, 'Hide posts by sync users that match filter regular expressions.']
    <% if (type !== 'crx') { %>
    'Automatic Updates': [true,  'Check for updates automatically.']
    <% } %>
  init: ->
    for setting, val of Settings.main
      stored = $.local.get setting
      Set[setting] = if stored is null then val[0] else stored is 'true'
    $.event 'AddSettingsSection',
      detail:
        title: 'Name Sync'
        open:  Settings.open
  open: (section) ->
    section.innerHTML = """
      <fieldset>
        <legend>Persona</legend>
        <div>
          <input type=text name=Name placeholder=Name>
          <input type=text name=Email placeholder=Email>
          <input type=text name=Subject placeholder=Subject>
        </div>
      </fieldset>
      <fieldset>
        <legend>Filter</legend>
        <p>Examples: ^(?!Anonymous$) to filter all names. !tripcode|!tripcode to filter multiple tripcodes.</p>
        <div>
          <input type=text name=FilterNames placeholder=Names>
          <input type=text name=FilterTripcodes placeholder=Tripcodes>
          <input type=text name=FilterEmails placeholder=Emails>
          <input type=text name=FilterSubjects placeholder=Subjects>
        </div>
      </fieldset>
      <fieldset>
        <legend>Advanced</legend>
        <div>
          <% if (type !== 'crx') { %>
          <input id=syncUpdate type=button value='Check for update'>
          <% } %>
          <input id=syncClear type=button value='Clear sync history' title='Clear your stored sync history from the server'>
          <input id=namesClear type=button value='Clear name cache' title='Clear locally stored names'>
        </div>
        <div>Sync Delay: <input type=number name=Delay min=0 step=100 placeholder=300 title='Delay before downloading new names when a new post is inserted'> ms</div>
      </fieldset>
      <fieldset>
        <legend>About</legend>
        <div>4chan X Name Sync v#{g.VERSION}</div>
        <div><a href='http://milkytiptoe.github.io/Name-Sync/' target='_blank'>Visit web page</a></div>
        <div><a href='https://github.com/milkytiptoe/Name-Sync/issues/new' target='_blank'>Report an issue</a></div>
        <div><a href='https://raw.github.com/milkytiptoe/Name-Sync/master/changelog' target='_blank'>View changelog</a></div>
      </fieldset>
      <img id=bgimage src='<%= meta.page %>namesync/bg.png' />
    """
    bgimage = $ '#bgimage', section
    bgimage.ondragstart = -> false
    bgimage.oncontextmenu = -> false
    field = $.el 'fieldset'
    $.add field, $.el 'legend',
      textContent: 'Main'

    for setting, val of Settings.main
      stored  = $.local.get setting
      istrue  = if stored is null then val[0] else stored is 'true'
      checked = if istrue then 'checked ' else ''
      $.add field, $.el 'div',
        innerHTML: "<label><input type='checkbox' name='#{setting}' #{checked}/>#{setting}</label><span class='description'>: #{val[1]}</span>"
    $.prepend section, field
    for check in $$ 'input[type=checkbox]', section
      $.on check, 'click', ->
        $.local.set @name, @checked

    for text in $$ 'input[type=text], input[type=number]', section
      text.value = $.local.get(text.name) or ''
      $.on text, 'input', ->
        if /^Filter/.test @name
          try
            regexp = RegExp @value
          catch err
            alert err.message
            return @value = $.local.get @name
        $.local.set @name, @value

    <% if (type !== 'crx') { %>
    $.on $('#syncUpdate', section), 'click', Updater.update
    <% } %>
    $.on $('#syncClear',  section), 'click', Sync.clear
    $.on $('#namesClear', section), 'click', Names.clear

Sync =
  lastModified: '0'
  disabled: false
  delay: null
  init: ->
    unless Set['Read-only Mode']
      $.on d, 'QRPostSuccessful', Sync.requestSend
    if g.threads.length is 1
      $.on d, 'ThreadUpdate', @checkThreadUpdate
      @sync true
    else
      @sync()
  checkThreadUpdate: (e) ->
    return unless e.detail.newPosts.length
    return Sync.disabled = true if e.detail[404]
    clearTimeout Sync.delay
    Sync.delay = setTimeout Sync.sync, $.local.get('Delay') or 300
  sync: (repeat) ->
    $.ajax 'qp',
      'GET'
      "t=#{g.threads}&b=#{g.board}"
      onloadend: ->
        return unless @status is 200 and @response
        Sync.lastModified = @getResponseHeader('Last-Modified') or Sync.lastModified
        for poster in JSON.parse @response
          Names.nameByPost[poster.p] = poster
        Names.updateAllPosts()
    if repeat and !Sync.disabled
      setTimeout Sync.sync, 30000, true
  requestSend: (e) ->
    postID   = e.detail.postID
    threadID = e.detail.threadID
    if Set['Persona Fields']
      currentName    = $.local.get('Name')    or ''
      currentEmail   = $.local.get('Email')   or ''
      currentSubject = $.local.get('Subject') or ''
    else
      qr             = $.id 'qr'
      currentName    = $('input[data-name=name]',  qr).value
      currentEmail   = $('input[data-name=email]', qr).value
      currentSubject = $('input[data-name=sub]',   qr).value
    currentName    = currentName.trim()
    currentEmail   = currentEmail.trim()
    currentSubject = currentSubject.trim()
    return if !$.session.get("#{g.board}-#{threadID}-last-name") and currentName+currentEmail+currentSubject is '' or Set['Hide Sage'] and /sage/i.test currentEmail
    $.session.set "#{g.board}-#{threadID}-last-name", currentName
    Sync.send currentName, currentEmail, currentSubject, postID, threadID
  send: (name, email, subject, postID, threadID) ->
    $.ajax 'sp',
      'POST'
      "p=#{postID}&t=#{threadID}&b=#{g.board}&n=#{encodeURIComponent name}&s=#{encodeURIComponent subject}&e=#{encodeURIComponent email}&dnt=#{if Set['Do Not Track'] then '1' else '0'}"
      onerror: ->
        setTimeout Sync.send, 2000, name, email, subject, postID, threadID
  clear: ->
    $('#syncClear').disabled = true
    $.ajax 'rm',
      'POST'
      ''
      onerror: ->
        $('#syncClear').value = 'Error'
      onloadend: ->
        return if @status isnt 200
        $('#syncClear').value = 'Cleared'

<% if (type !== 'crx') { %>
Updater =
  init: ->
    last = $.local.get 'lastcheck'
    if last is null or Date.now() > last + 86400000
      @update()
  update: ->
    $('#syncUpdate').disabled = true
    $.ajax 'u3',
      'GET'
      ''
      onloadend: ->
        $.local.set 'lastcheck', Date.now()
        if @status isnt 200 or @response is g.VERSION
          return $('#syncUpdate').value = 'None available'
        $.event 'CreateNotification',
          detail:
            type: 'info'
            content: $.el 'span',
              innerHTML: "An update for 4chan X Name Sync is available.<% if (type === 'userscript') { %> <a href=<%= meta.builds %>firefox/NameSync.user.js target=_blank>Install now</a>. <% } else { %> <a href=<%= meta.page %> target=_blank>Get it here</a>.<% } %>"
            lifetime: 10
        $('#fourchanx-settings .close').click()
<% } %>

$.on d, '4chanXInitFinished', Main.init
