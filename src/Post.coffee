# This file contains code from 4chan X (https://github.com/MayhemYDG/4chan-x)
# @license: https://github.com/MayhemYDG/4chan-x/blob/v3/LICENSE
class Post
  toString: -> @ID

  constructor: (root) ->
    @ID    = root.id[2..]

    post   = $ '.post',     root
    info   = $ '.postInfo', post
    @nodes =
      root: root
      post: post
      info: info

    @isReply = $.hasClass post, 'reply'

    @info = {}

    unless subject    = $ '.subject',        info
      subject = $.el 'span', className: 'subject'
      $.after $('[type="checkbox"]', info), [$.tn ' '; subject]
    @nodes.subject    = subject

    if name           = $ '.name',           info
      @nodes.name     = name
    if capcode        = $ '.capcode.hand',   info
      @info.capcode   = capcode.textContent.replace '## ', ''
    if date           = $ '.dateTime',       info
      @info.date      = date.dataset.utc
    if uID            = $ '.posteruid .hand', info
      @info.uID       = uID.textContent
