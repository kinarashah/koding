jraphical   = require 'jraphical'
KodingError = require '../error'
ApiError    = require './socialapi/error'

{argv}      = require 'optimist'
KONFIG      = require('koding-config-manager').load("main.#{argv.c}")

module.exports = class JAccount extends jraphical.Module

  @trait __dirname, '../traits/followable'
  @trait __dirname, '../traits/filterable'
  @trait __dirname, '../traits/taggable'
  @trait __dirname, '../traits/notifying'
  @trait __dirname, '../traits/flaggable'

  JStorage         = require './storage'
  JAppStorage      = require './appstorage'
  JTag             = require './tag'
  JName            = require './name'
  JKite            = require './kite'
  JReferrableEmail = require './referrableemail'

  @getFlagRole            = 'content'
  @lastUserCountFetchTime = 0

  {ObjectId, Register, secure, race, dash, daisy, signature} = require 'bongo'
  {Relationship} = jraphical
  {permit} = require './group/permissionset'
  Validators = require './group/validators'
  Protected = require '../traits/protected'
  {extend} = require 'underscore'

  validateFullName = (value) -> not /<|>/.test value

  @share()

  @set
    softDelete          : yes
    emitFollowingActivities : yes # create buckets for follower / followees
    tagRole             : 'skill'
    taggedContentRole   : 'developer'
    indexes:
      'profile.nickname' : 'unique'
      isExempt           : 'ascending'
      type               : 'ascending'
    sharedEvents    :
      static        : [
        { name : 'AccountAuthenticated' } # TODO: we need to handle this event differently.
        { name : 'RemovedFromCollection' }
      ]
      instance      : [
        # this is commented-out intentionally
        # when a user sends a status update, we are sending 7 events
        # when a user logs-in we are sending 10 events
        # { name: 'updateInstance' }
        { name : 'messageBusEvent' }
        { name : 'RemovedFromCollection' }
        { name : 'NewWorkspaceCreated'}
      ]
    sharedMethods :
      static:
        one: [
          (signature Object, Function)
          (signature Object, Object, Function)
        ]
        some:
          (signature Object, Object, Function)
        cursor:
          (signature Object, Object, Function)
        each: [
          (signature Object, Object, Function)
          (signature Object, Object, Object, Function)
        ]
        someWithRelationship:
          (signature Object, Object, Function)
        someData:
          (signature Object, Object, Object, Function)
        getAutoCompleteData:
          (signature String, String, Function)
        count: [
          (signature Function)
          (signature Object, Function)
        ]
        byRelevance: [
          (signature String, Function)
          (signature String, Object, Function)
        ]
        fetchVersion:
          (signature Function)
        reserveNames: [
          (signature Function)
          (signature Object, Function)
        ]
        verifyEmailByUsername:
          (signature String, Function)
        fetchBlockedUsers:
          (signature Object, Function)
        fetchCachedUserCount:
          (signature Function)

      instance:
        modify:
          (signature Object, Function)
        follow: [
          (signature Function)
          (signature Object, Function)
        ]
        unfollow: [
          (signature Function)
        ]
        fetchTopics:
          (signature Object, Object, Function)
        fetchAppStorage:
          (signature Object, Function)
        addTags: [
          (signature Object, Function)
          (signature Object, Object, Function)
        ]
        setEmailPreferences:
          (signature Object, Function)
        fetchRole:
          (signature Function)
        flagAccount:
          (signature String, Function)
        unflagAccount:
          (signature String, Function)
        isFollowing:
          (signature String, String, Function)
        updateFlags:
          (signature [String], Function)
        fetchGroups: [
          (signature Function)
          (signature Object, Function)
        ]
        fetchGroupRoles:
          (signature String, Function)
        fetchGroupsWithPendingInvitations: [
          (signature Function)
          (signature Object, Function)
        ]
        fetchGroupsWithPendingRequests: [
          (signature Function)
          (signature Object, Function)
        ]
        cancelRequest:
          (signature String, Function)
        acceptInvitation:
          (signature String, Function)
        ignoreInvitation:
          (signature String, Function)
        fetchMyGroupInvitationStatus:
          (signature String, Function)
        fetchMyPermissions:
          (signature Function)
        fetchMyPermissionsAndRoles:
          (signature Function)
        blockUser: [
          (signature String, Number, Function)
          (signature ObjectId, Number, Function)
        ]
        unblockUser: [
          (signature String, Function)
          (signature ObjectId, Function)
        ]
        unlinkOauth:
          (signature String, Function)
        markUserAsExempt:
          (signature Boolean, Function)
        userIsExempt:
          (signature Function)
        checkGroupMembership:
          (signature String, Function)
        fetchStorage:
          (signature String, Function)
        fetchStorages:
          (signature [String], Function)
        store:
          (signature Object, Function)
        unstore:
          (signature String, Function)
        isEmailVerified:
          (signature Function)
        fetchEmail:
          (signature Function)
        fetchPaymentMethods:
          (signature Function)
        fetchSubscriptions: [
          (signature Function)
          (signature Object, Function)
        ]
        fetchPlansAndSubscriptions: [
          (signature Function)
          (signature Object, Function)
        ]
        fetchEmailAndStatus:
          (signature Function)
        fetchEmailFrequency:
          (signature Function)
        fetchOAuthInfo:
          (signature Function)
        fetchFromUser:
          (signature String, Function)
        likeMember:
          (signature String, Function)
        fetchKites :
          (signature Object, Function)
        fetchMetaInformation :
          (signature Function)
        setLastLoginTimezoneOffset:
          (signature Object, Function)
        expireSubscription:
          (signature Function)
        fetchOtaToken:
          (signature Function)

    schema                  :
      shareLocation         : Boolean
      socialApiId           : String
      skillTags             : [String]
      locationTags          : [String]
      systemInfo            :
        defaultToLastUsedEnvironment :
          type              : Boolean
          default           : yes
      # counts                : Followable.schema.counts
      counts                :
        followers           :
          type              : Number
          default           : 0
        following           :
          type              : Number
          default           : 0
        topics              :
          type              : Number
          default           : 0
        likes               :
          type              : Number
          default           : 0

      environmentIsCreated  : Boolean
      type                  :
        type                : String
        enum                : ['invalid account type',[
                                'registered'
                                'unregistered'
                                'deleted'
                              ]]
        default             : 'unregistered'
      profile               :
        about               : String
        nickname            :
          type              : String
          validate          : require('./name').validateName
          set               : (value)-> value.toLowerCase()
        hash                : String
        ircNickname         : String
        firstName           :
          type              : String
          required          : yes
          default           : 'a koding'
          validate          : validateFullName
        lastName            :
          type              : String
          default           : 'user'
          validate          : validateFullName
        description         : String
        avatar              : String
        status              : String
        experience          : String
        experiencePoints    :
          type              : Number
          default           : 0
        lastStatusUpdate    : String
      referrerUsername      : String
      referralUsed          : Boolean
      preferredKDProxyDomain: String
      isExempt              : # is a troll ?
        type                : Boolean
        default             : false
      globalFlags           : [String]
      meta                  : require 'bongo/bundles/meta'
      onlineStatus          :
        type                : String
        enum                : ['invalid status',['online','offline','away','busy']]
        default             : 'online'
    broadcastableRelationships : [ 'follower' ]
    relationships           : ->

      appStorage    :
        as          : 'appStorage'
        targetType  : "JAppStorage"

      storage       :
        as          : 'storage'
        targetType  : 'JStorage'

      tag:
        as          : 'skill'
        targetType  : "JTag"

      domain        :
        as          : 'owner'
        targetType  : 'JProposedDomain'

      proxyFilter   :
        as          : 'owner'
        targetType  : 'JProxyFilter'

      referrer      :
        targetType  : 'JReferral'
        as          : 'referrer'
      referred      :
        targetType  : 'JReferral'
        as          : 'referred'
      invitation    :
        as          : 'owner'
        targetType  : 'JInvitation'

      invitationRequest :
        as          : 'owner'
        targetType  : 'JInvitationRequest'

      paymentMethod :
        as          : 'payment method'
        targetType  : 'JPaymentMethod'

      subscription  :
        as          : 'service subscription'
        targetType  : 'JPaymentSubscription'

      kite          :
        as          : 'owner'
        targetType  : JKite

      credential    :
        as          : ['owner', 'user']
        targetType  : 'JCredential'

      stackTemplate :
        as          : 'user'
        targetType  : 'JStackTemplate'


  constructor:->
    super
    @notifyOriginWhen 'PrivateMessageSent', 'FollowHappened'
    @notifyGroupWhen 'FollowHappened'

  @sendUpdateInstanceEvent = (obj, op) =>
    JAccount.bongos.forEach (bongo) =>
      bongo.handleEvent "instance", obj, "updateInstance", [op]

  canEditPost: permit 'edit posts'

  canDeletePost: permit 'delete posts'

  createSocialApiId:(callback)->
    if @type is 'unregistered'
      return callback null, -1

    return callback null, @socialApiId  if @socialApiId
    {createAccount} = require './socialapi/requests'
    createAccount {id: @getId(), nickname: @profile.nickname}, (err, account)=>
      return callback new ApiError err  if err
      return callback {message: "Account is not set, malformed response from social api"} unless account?.id
      @update $set: socialApiId: account.id, isExempt: account.isTroll, (err)->
        # check for error
        if err
          console.error "Error while creating account on social api", err
          return callback { message: "Couldnt create/register Account"}
        # check account
        # return account id from social api
        return callback null, account.id

  checkGroupMembership: secure (client, groupName, callback)->
    {delegate} = client.connection
    JGroup = require "./group"
    JGroup.one {slug : groupName}, (err, group)->
      return callback new KodingError "An error occurred!" if err
      return callback null, no unless group

      Relationship.one {
        as          : 'member'
        targetId    : delegate.getId()
        sourceId    : group.getId()
      }, (err, relation)=>
        return callback new KodingError "An error occurred!" if err
        return callback null, relation?

  changeUsername: (options, callback = (->)) ->
    { username, isRegistration } = options
    oldUsername = @profile.nickname

    if username is oldUsername

      if isRegistration

        # To keep safe all other listeners of 'UsernameChanged' event
        # we are checking for the `isRegistration` flag before returning
        # error here. Instead in here we are faking like we did the
        # username change sucessfully. ~ GG

        @constructor.emit 'UsernameChanged', {
          oldUsername, username, isRegistration
        }
        return callback null

      else
        return callback new KodingError "Username was not changed!"

    # Validate username
    unless @constructor.validateAt 'profile.nickname', username
      return callback new KodingError 'Invalid username!'

    # Custom error helper, we are using it to free up new JName
    # for given username, if any error happens after JName creation.
    hasError = (err) ->
      if err?
        JName.remove name: username, ->
          callback err
        return yes

    # Create JName for new username
    name    = new JName
      name  : username
      slugs : [
        constructorName : 'JUser'
        collectionName  : 'jUsers'
        slug            : username
        usedAsPath      : 'username'
      ]

    name.save (err) =>

      return  if err?

        # If failed to save with duplicate error, return a custom error
        if err?.code is 11000
          callback new KodingError 'Username is not available!'
        else
          callback err

      # Find the JUser assigned to this JAccount
      @fetchUser (err, user) =>
        return  if hasError err

        # Update it's username field too
        user.update { $set: { username, oldUsername } }, (err) =>
          return  if hasError err

          # Update profile.nickname
          @update { $set: 'profile.nickname': username }, (err) =>
            return  if hasError err

            # Emit the change, let the whole system knows
            change = { oldUsername, username, isRegistration }
            @constructor.emit 'UsernameChanged', change

            callback null

            # Free up the old username
            JName.remove name: oldUsername, (err) ->
              console.warn "[JAccount.changeUsername]", err  if err?


  checkPermission: (target, permission, callback)->
    JPermissionSet = require './group/permissionset'
    client =
      context     : { group: target.slug }
      connection  : { delegate: this }
    advanced =
      if Array.isArray permission then permission
      else JPermissionSet.wrapPermission permission
    JPermissionSet.checkPermission client, advanced, target, null, callback

  @renderHomepage: require '../render/profile.coffee'

  @fetchCachedUserCount: (callback)->
    if (Date.now() - @lastUserCountFetchTime)/1000 < 60
      return callback null, @cachedUserCount
    JAccount.count type:'registered', (err, count)=>
      return callback err if err
      @lastUserCountFetchTime = Date.now()
      @cachedUserCount = count
      callback null, count

  fetchHomepageView:(options, callback)->
    {account} = options

    homePageOptions = extend options, {
      renderedAccount : account
      account         : this
      isLoggedIn      : account.type is 'unregistered'
    }

    JAccount.renderHomepage homePageOptions, callback

  fetchGroups: secure (client, options, callback)->
    [callback, options] = [options, callback]  unless callback
    options       ?= {}
    JGroup        = require './group'
    {groupBy}     = require 'underscore'
    {delegate}    = client.connection
    isMine        = @equals delegate
    edgeSelector  =
      sourceName  : 'JGroup'
      targetId    : @getId()
      as          : 'member'
    edgeFields    =
      sourceId    : 1
      as          : 1
    edgeOptions   =
      sort        : options.sort  or { timestamp: -1 }
      limit       : options.limit or 20
      skip        : options.skip  or 0
    Relationship.someData edgeSelector, edgeFields, options, (err, cursor)->
      if err then callback err
      else
        cursor.toArray (err, docs)->
          if err then callback err
          else unless docs
            callback null, []
          else
            groupedDocs = groupBy docs, 'sourceId'
            targetSelector = { _id: $in: (doc.sourceId for doc in docs) }
            targetSelector.visibility = 'visible'  unless isMine
            JGroup.all targetSelector, (err, groups)->
              if err then callback err
              else callback null, groups.map (group)->
                roles = (doc.as for doc in groupedDocs[group.getId()])
                return { group, roles }

  fetchGroupRoles: secure (client, slug, callback)->
    {delegate} = client.connection
    JGroup     = require './group'
    JGroup.fetchIdBySlug slug, (err, groupId)->
      if err then callback err
      else
        selector = {
          sourceId: groupId
          targetId: delegate.getId()
        }
        Relationship.someData selector, {as:1}, (err, cursor)->
          if err then callback err
          else
            cursor.toArray (err, arr)->
              if err then callback err
              else callback null, (doc.as for doc in arr)

  @verifyEmailByUsername = secure (client, username, callback)->
    {connection:{delegate}, sessionToken} = client
    unless delegate.can 'verify-emails'
      callback new KodingError 'Access denied'
    else
      JUser = require './user'
      JUser.one {username}, (err, user)->
        return  callback err if err
        return  callback new Error "User is not found" unless user
        user.confirmEmail (err)->
          return callback new Error "An error occurred while confirming email" if err
          callback null, yes

  @reserveNames =(options, callback)->
    [callback, options] = [options, callback]  unless callback
    options       ?= {}
    options.limit ?= 100
    options.skip  ?= 0
    @someData {}, {'profile.nickname':1}, options, (err, cursor)=>
      if err then callback err
      else
        count = 0
        cursor.each (err, account)=>
          if err then callback err
          else if account?
            {nickname} = account.profile
            JName.claim nickname, 'JUser', 'username', (err, name)=>
              count++
              if err then callback err
              else
                callback err, nickname
                if count is options.limit
                  options.skip += options.limit
                  @reserveNames options, callback

  @fetchVersion =(callback)-> callback null, KONFIG.version

  @fetchBlockedUsers = secure ({connection:{delegate}}, options, callback) ->
    unless delegate.can 'list-blocked-users'
      return callback new KodingError 'Access denied!'

    selector = blockedUntil: $gte: new Date()

    options.limit = Math.min options.limit ? 20, 20
    options.skip ?= 0

    fields = { username:1, blockedUntil:1 }

    JUser = require './user'
    JUser.someData selector, fields, options, (err, cursor) ->
      return callback err  if err?
      cursor.toArray (err, users) ->
        return callback err       if err?
        return callback null, []  if users.length is 0

        users.sort (a, b) -> a.username < b.username

        acctSelector = 'profile.nickname': $in: users.map (u) -> u.username

        JAccount.some acctSelector, {}, (err, accounts)=>
          if err
            callback err
          else
            accounts.sort (a, b) -> a.profile.nickname < b.profile.nickname
            for user, i in users
              accounts[i].blockedUntil = users[i].blockedUntil
            callback null, accounts


  @findSuggestions = (client, seed, options, callback)->
    {limit, blacklist, skip}  = options
    ### TODO:
    It is highly dependent to culture and there are even onces w/o the concept
    of first and last names. For now we assume last part of the seed is the lastname
    and the whole except last part is the first name. Not ideal but covers more
    than previous implementation. This implementation would fail if I type my
    two firstnames only, it will assume second part is my lastname.
    Ideal solution is to check the seed against firstName + ' ' + lastName instead of
    deciding ourselves which parts of the search are for first or last name.
    MongoDB 2.4 and bongo implementation of aggregate required to use $concat
    ###
    names = seed.toString().split('/')[1].replace(/[\\^]/g, "").split ' '
    names.push names.first if names.length is 1
    @some {
      $or : [
          ( 'profile.nickname'  : seed )
          ( 'profile.firstName' : new RegExp '^'+names.slice(0, -1).join(' '), 'i' )
          ( 'profile.lastName'  : new RegExp '^'+names.last, 'i' )
        ],
      _id     :
        $nin  : blacklist
      type    :
        $in   : ['registered', null]
    },{
      skip
      limit
      sort    : 'profile.firstName' : 1
    }, callback

  @getAutoCompleteData = (fieldString, queryString, callback)->
    query = {}
    desiredData = {}
    query[fieldString] = RegExp queryString, 'i'
    desiredData[fieldString] = yes
    @someData query, desiredData, (err, cursor)->
      cursor.toArray (err, docs)->
        results = []
        for doc in docs
          results.push doc.profile.fullname
        callback err, results

  # I wrote it and decided that it is not necessary, feel free to remove ~ GG
  #
  # @filterUsernames = permit 'list members',
  #   success: (client, nick, options, callback)->
  #     [callback, options] = [options, callback]  unless callback
  #     options or= {}
  #     options.limit = 10
  #     query = 'profile.nickname' : ///^#{nick}///
  #     @some query, options, callback

  setEmailPreferences: (user, prefs, callback)->
    current = user.getAt('emailFrequency') or {}
    Object.keys(prefs).forEach (granularity)->
      state = prefs[granularity]
      current[granularity] = state# then 'instant' else 'never'

    updateUserPref =->
      user.update {$set: emailFrequency: current}, (err)->
        return callback err  if err

    updateUserPref()

  setEmailPreferences$: secure (client, prefs, callback)->
    JUser = require './user'
    JUser.fetchUser client, (err, user)=>
      if err
        callback err
      else
        @setEmailPreferences user, prefs, callback

  # Update broken counts for user
  updateCounts:->
    JUser = require './user'
    # ReferredUsers count
    JAccount.count
      referrerUsername : @profile.nickname
    , (err, count)=>
      return if err
      count ?= 0
      @update ($set: 'counts.referredUsers': count), ->

    # Invitations count
    JReferrableEmail.count
      username   : @profile.nickname
      invited    : true
    , (err, count)=>
      return if err
      count ?= 0
      @update ($set: 'counts.invitations': count), ->

    # Last Login date
    @update ($set: 'counts.lastLoginDate': new Date), ->

    # Twitter follower count
    JUser.one {username: @profile.nickname}, (err, user)=>
      return if err or not user
      if user.foreignAuth?.twitter?
        followerCount = user.foreignAuth.twitter.profile.followers_count
        @update ($set: 'counts.twitterFollowers': followerCount), ->


  dummyAdmins = [ "sinan", "devrim", "gokmen", "fatihacet", "arslan",
                  "sent-hil", "cihangirsavas", "leeolayvar", "stefanbc",
                  "szkl", "canthefason", "nitin", "usirin"]

  userIsExempt: (callback)->
    # console.log @isExempt, this
    callback null, @isExempt

  # returns troll users ids
  #
  # Adding a temporary limit of 100. We currently've 24 trolls, by the
  # time this limit runs out we'll have switched to a scalable model of
  # filtering troll users. SA
  @getExemptUserIds: (callback)->
    JAccount.someData {isExempt:true}, {_id:1, limit:100}, {sort:_id:-1}, (err, cursor)->
      return callback err, null if err
      ids = []
      cursor.each (err, account)->
        return callback err, null if err
        if account
            ids.push account._id.toString()
        else
            callback null, ids

  isEmailVerified: (callback)->
    @fetchUser (err, user)->
      return callback err if err
      callback null, (user.status is "confirmed")

  markUserAsExempt: secure (client, exempt, callback)->
    {delegate} = client.connection
    return callback new KodingError 'Access denied'  unless delegate.can 'flag', this
    return @markUserAsExemptUnsafe client, exempt, callback

  markUserAsExemptUnsafe: (client, exempt, callback)->
    # mark user as troll in social api
    @markUserAsExemptInSocialAPI client, exempt, (err, data)=>
      return callback new ApiError err  if err
      op = $set: {isExempt: exempt}
      @update op, (err, result)=>
        if err
          console.error 'Could not update user exempt information'
          return callback err
        @isExempt = exempt

        JAccount.sendUpdateInstanceEvent this, op
        callback null, result

  markUserAsExemptInSocialAPI: (client, exempt, callback)->
    {markAsTroll, unmarkAsTroll} = require './socialapi/requests'
    @createSocialApiId (err, accountId)->
      return callback err  if err
      return callback {message: "account id is not set"} unless accountId

      if exempt
        markAsTroll {accountId}, callback
      else
        unmarkAsTroll {accountId}, callback

  flagAccount: secure (client, flag, callback)->
    {delegate} = client.connection
    JAccount.taint @getId()
    if delegate.can 'flag', this
      @update {$addToSet: globalFlags: flag}, callback
    else
      callback new KodingError 'Access denied'

  unflagAccount: secure (client, flag, callback)->
    {delegate} = client.connection
    JAccount.taint @getId()
    if delegate.can 'flag', this
      @update {$pullAll: globalFlags: [flag]}, callback
    else
      callback new KodingError 'Access denied'

  updateFlags: secure (client, flags, callback)->
    {delegate} = client.connection
    JAccount.taint @getId()
    if delegate.can 'flag', this
      @update {$set: globalFlags: flags}, callback
    else
      callback new KodingError 'Access denied'

  fetchUserByAccountIdOrNickname:(accountIdOrNickname, callback)->

    kallback= (err, account)->
      return callback err if err
      JUser = require './user'
      JUser.one {username: account.profile.nickname}, (err, user)->
        callback err, {user, account}


    JAccount.one { 'profile.nickname' : accountIdOrNickname }, (err, account)->
      return kallback err, account if account
      JAccount.one  { _id : accountIdOrNickname }, (err, account)->
        return kallback err, account if account
        callback new KodingError 'Account not found'


  blockUser: secure (client, accountIdOrNickname, durationMillis, callback)->
    {delegate} = client.connection
    if delegate.can('flag', this) and accountIdOrNickname? and durationMillis?
      @fetchUserByAccountIdOrNickname accountIdOrNickname, (err, {user, account})->
        return callback err if err
        blockedDate = new Date(Date.now() + durationMillis)
        account.sendNotification 'UserBlocked', { blockedDate }
        user.block blockedDate, callback
    else
      callback new KodingError 'Access denied'

  unblockUser: secure (client, accountIdOrNickname, callback)->
    {delegate} = client.connection
    if delegate.can('flag', this) and accountIdOrNickname?
      @fetchUserByAccountIdOrNickname accountIdOrNickname, (err, {user})->
        return callback err if err
        user.unblock callback
    else
      callback new KodingError 'Access denied'

  checkFlag: (flagToCheck) ->
    flags = @getAt('globalFlags')
    if flags
      if 'string' is typeof flagToCheck
        return flagToCheck in flags
      else
        for flag in flagToCheck
          if flag in flags
            return yes
    return no

  isDummyAdmin = (nickname)-> !!(nickname in dummyAdmins)

  @getFlagRole =-> 'owner'

  # WARNING! Be sure everything is safe when you change anything in this function
  can:(action, target)->
    switch action
      when 'delete'
        # Users can delete their stuff but super-admins can delete all of them ಠ_ಠ
        @profile.nickname in dummyAdmins or target?.originId?.equals @getId()
      when 'flag', 'reset guests', 'reset groups', 'administer names',        \
           'administer url aliases', 'administer accounts', 'search-by-email',\
           'migrate-koding-users', 'list-blocked-users', 'verify-emails',     \
           'bypass-validations'
        @profile.nickname in dummyAdmins

  fetchRoles: (group, callback)->
    Relationship.someData {
      targetId: group.getId()
      sourceId: @getId()
    }, {as:1}, (err, cursor)->
      if err
        callback err
      else
        cursor.toArray (err, roles)->
          if err
            callback err
          else
            roles = (roles ? []).map (role)-> role.as
            roles.push 'guest' unless roles.length
            callback null, roles

  fetchRole: secure ({connection}, callback)->

    if isDummyAdmin connection.delegate.profile.nickname
      callback null, "super-admin"
    else
      callback null, "regular"

  # temp dummy stuff ends

  fetchPrivateChannel:(callback)->
    require('bongo').fetchChannel @getPrivateChannelName(), callback

  getPrivateChannelName:-> "private-#{@getAt('pro file.nickname')}-private"

  fetchTopics: secure (client, query, page, callback)->
    query       =
      targetId  : @getId()
      as        : 'follower'
      sourceName: 'JTag'
    Relationship.some query, page, (err, docs)->
      if err then callback err
      else
        {group} = client.context
        ids = (rel.sourceId for rel in docs)
        selector = _id: $in: ids
        selector.group = group if group isnt 'koding'
        JTag.all selector, (err, tags)->
          callback err, tags

  modify: secure (client, fields, callback) ->

    allowedFields = [
      "preferredKDProxyDomain"
      "profile.about"
      "profile.description"
      "profile.ircNickname"
      "profile.firstName"
      "profile.lastName"
      "profile.avatar"
      "profile.experience"
      "profile.experiencePoints"
      "skillTags"
      "locationTags"
      "shareLocation"
    ]

    objKeys = Object.keys(fields)

    for objKey in objKeys
      if objKey not in allowedFields
        return callback new KodingError "Modify fields is not valid"

    if @equals(client.connection.delegate)
      op = $set: fields
      @update op, (err) =>
        JAccount.sendUpdateInstanceEvent this, op  unless err
        SocialAccount  = require './socialapi/socialaccount'

        SocialAccount.update {
          id            : @socialApiId
          nick          : @profile.nickname
          settings      : {shareLocation: fields.shareLocation}
        }, callback

  setClientId:(@clientId)->

  getFullName:->
    {firstName, lastName} = @data.profile
    return "#{firstName} #{lastName}"

  fetchStorage$: (name, callback)->

    @fetchStorage { 'data.name' : name }, callback

  fetchStorages$: (whitelist=[], callback)->

    options = if whitelist.length then { 'data.name' : $in : whitelist } else {}

    @fetchStorages options, callback

  store: secure (client, {name, content}, callback)->
    unless @equals client.connection.delegate
      return callback new KodingError "Attempt to access unauthorized storage"

    @_store {name, content}, callback

  unstore: secure (client, name, callback)->

    unless @equals client.connection.delegate
      return callback new KodingError "Attempt to remove unauthorized storage"

    @fetchStorage { 'data.name' : name }, (err, storage)=>
      console.error err, storage  if err
      return callback err  if err
      unless storage
        return callback new KodingError "No such storage"

      storage.remove callback

  unstoreAll: (callback)->
    @fetchStorages [], (err, storages)->
      daisy queue = storages.map (storage) ->
        -> storage.remove -> queue.next()
      queue.push -> callback null

  _store: ({name, content}, callback)->
    @fetchStorage { 'data.name' : name }, (err, storage)=>
      if err
        return callback new KodingError "Attempt to access storage failed"
      else if storage
        storage.update $set: {content}, (err) -> callback err, storage
      else
        storage = new JStorage {name, content}
        storage.save (err)=>
          return callback err  if err
          rel = new Relationship
            targetId    : storage.getId()
            targetName  : 'JStorage'
            sourceId    : @getId()
            sourceName  : 'JAccount'
            as          : 'storage'
            data        : {name}
          rel.save (err)-> callback err, storage

  fetchOrCreateAppStorage: (options, callback) ->
    {appId, version} = options
    @fetchAppStorage {'data.appId':appId, 'data.version':version}, (err, storage)=>
      if err then callback err
      else unless storage?
        # log.info 'Creating new storage:', appId, version, @profile.nickname
        newStorage = new JAppStorage {appId, version}
        newStorage.save (err) =>
          if err then callback err
          else
            # manually add the relationship so that we can
            # query the edge instead of the target C.T.
            rel = new Relationship
              targetId    : newStorage.getId()
              targetName  : 'JAppStorage'
              sourceId    : @getId()
              sourceName  : 'JAccount'
              as          : 'appStorage'
              data        : {appId, version}
            rel.save (err)-> callback err, newStorage
      else
        callback err, storage

  fetchAppStorage$: secure (client, options, callback) ->

    unless client?.connection?.delegate
      return callback "Not a valid session"

    unless @equals client.connection.delegate
      return callback "Attempt to access unauthorized application storage"

    @fetchOrCreateAppStorage options, callback

  fetchUser:(callback)->
    JUser = require './user'
    if /^guest-/.test @profile.nickname
      user = new JUser()
      user.username = @profile.nickname
      return callback null, user

    JUser.one {username: @profile.nickname}, callback

  @taintedAccounts = {}
  @taint =(id)->
    @taintedAccounts[id] = yes

  @untaint =(id)->
    delete @taintedAccounts[id]

  @isTainted =(id)->
    isTainted = @taintedAccounts[id]
    isTainted

  sendNotification: (event, contents) ->
    @createSocialApiId (err, socialApiId) =>
      return console.error "Could not send notification to account:", err  if err

      message = {
        account: {id: socialApiId, nick: @profile.nickname}
        eventName: "social"
        body:
          contents: contents
          event: event
          context: "koding"
      }

      @emit 'messageBusEvent', {type: "dispatcher_notify_user", message: message}

  fetchGroupsWithPending:(method, status, options, callback)->
    [callback, options] = [options, callback]  unless callback
    options ?= {}

    selector    = {}
    if options.groupIds
      selector.sourceId = $in:(ObjectId groupId for groupId in options.groupIds)
      delete options.groupIds

    relOptions = targetOptions: selector: {status}

    @["fetchInvitation#{method}s"] {}, relOptions, (err, rels)->
      return callback err  if err
      JGroup = require './group'
      JGroup.some _id:$in:(rel.sourceId for rel in rels), options, callback

  fetchGroupsWithPendingRequests:(options, callback)->
    @fetchGroupsWithPending 'Request', 'pending', options, callback

  fetchGroupsWithPendingInvitations:(options, callback)->
    @fetchGroupsWithPending '', 'sent', options, callback

  fetchMyGroupInvitationStatus: secure (client, slug, callback)->
    return  unless @equals client.connection.delegate

    JGroup = require './group'

    JGroup.one { slug }, (err, group) ->
      return callback err  if err

      selector = sourceId: group.getId()

      options = targetOptions: selector: status: 'pending'
      @fetchInvitationRequests selector, options, (err, requests)=>
        return callback err                if err
        return callback null, 'requested'  if requests?[0]

        options = targetOptions: selector: status: 'sent'
        @fetchInvitations selector, options, (err, invites)=>
          return callback err              if err
          return callback null, 'invited'  if invites?[0]
          return callback null, no

  cancelRequest: secure (client, slug, callback)->
    options = targetOptions: selector: status: 'pending'
    JGroup = require './group'

    JGroup.one { slug }, (err, group) ->
      return callback err  if err

      @fetchInvitationRequests {sourceId: group.getId()}, options, (err, [request])->
        return callback err                                  if err
        return callback 'could not find invitation request'  unless request
        request.remove callback

  fetchInvitationByGroupSlug:(slug, callback)->
    options = targetOptions: selector: {status: 'sent', group: slug}
    @fetchInvitations {}, options, (err, [invite])->
      return callback err                          if err
      return callback 'could not find invitation'  unless invite

      JGroup = require './group'
      JGroup.one { slug }, (err, groupObj)->
        return callback err  if err
        callback null, { invite, group: groupObj }

  acceptInvitation: secure (client, slug, callback)->
    @fetchInvitationByGroupSlug slug, (err, { invite, group })=>
      return callback err  if err
      groupObj.approveMember this, (err)->
        return callback err  if err
        invite.update $set:status:'accepted', callback

  ignoreInvitation: secure (client, slug, callback)->
    @fetchInvitationByGroupSlug slug, (err, { invite })->
      return callback err  if err
      invite.update $set:status:'ignored', callback

  @byRelevance$ = permit 'list members',
    success: (client, seed, options, callback)->
      if options.byEmail
        account = client.connection.delegate
        if account.can 'search-by-email'
          JUser = require './user'
          JUser.one {email:seed}, (err, user)->
            return callback err, []  if err? or not user?
            user.fetchOwnAccount (err, account)->
              return callback err  if err?
              callback null, [account]
        else
          return callback new KodingError 'Access denied'
      else
        @byRelevance client, seed, options, callback

  fetchMyPermissions: secure (client, callback)->
    @fetchMyPermissionsAndRoles client, (err, permissions, roles)->
      callback err, permissions

  fetchMyPermissionsAndRoles: secure (client, callback)->
    JGroup = require './group'

    slug = client.context.group ? 'koding'
    JGroup.one {slug}, (err, group)=>
      return callback err  if err
      return callback {message: "group not found"}  unless group

      kallback = (err, roles)=>
        return callback err  if err

        @fetchUser (err, user)=>
          return callback err  if err

          userId = user._id

          {flatten} = require 'underscore'

          if "admin" in roles

            perms = Protected.permissionsByModule
            callback null, { permissions: (flatten perms), roles, userId }

          else

            group.fetchPermissionSetOrDefault (err, permissionSet)->
              return callback err if err

              perms = (perm.permissions.slice() for perm in permissionSet.permissions \
                when perm.role in roles or 'admin' in roles)

              callback null, { permissions: (flatten perms), roles, userId }

      group.fetchMyRoles client, kallback

  oldAddTags = @::addTags
  addTags: secure (client, tags, options, callback)->
    client.context.group = 'koding'
    oldAddTags.call this, client, tags, options, callback

  ## NEWER IMPLEMENATION: Fetch ids from graph db, get items from document db.

  unlinkOauth: secure (client, provider, callback)->
    {delegate} = client.connection
    isMine     = @equals delegate
    if isMine
      @fetchUser (err, user)=>
        return callback err  if err

        query = {}
        query["foreignAuth.#{provider}"] = ""
        user.update $unset: query, (err)=>
          return callback err  if err
          @oauthDeleteCallback provider, user, callback
    else
      callback new KodingError 'Access denied'

  oauthDeleteCallback: (provider, user, callback)->
    if provider is "google"
      user.fetchAccount 'koding', (err, account)->
        return callback err  if err
        JReferrableEmail = require "./referrableemail"
        JReferrableEmail.delete user.username, callback
    else
      callback()

  # we are using this in sorting members list..
  updateMetaModifiedAt: (callback)->
    @update $set: 'meta.modifiedAt': new Date, callback

  fetchEmail: secure (client, callback)->
    {delegate} = client.connection
    isMine     = @equals delegate
    if isMine
      @fetchUser (err, user)->
        return callback err  if err
        callback null, user?.email
    else
      callback new KodingError 'Access denied'

  fetchDecoratedPaymentMethods: (callback) ->
    JPaymentMethod = require './payment/method'
    @fetchPaymentMethods (err, paymentMethods) ->
      return callback err  if err
      JPaymentMethod.decoratePaymentMethods paymentMethods, callback

  fetchPaymentMethods$: secure (client, callback) ->
    {delegate} = client.connection
    if (delegate.equals this) or delegate.can 'administer accounts'
      @fetchDecoratedPaymentMethods callback


  fetchMetaInformation: secure (client, callback)->

    {delegate} = client.connection
    unless delegate.can 'administer accounts'
      return callback new KodingError 'Access denied!'

    Payment = require './payment'

    @fetchUser (err, user)=>

      return callback err  if err
      return callback new KodingError 'Failed to fetch user!'  unless user

      { registeredAt, lastLoginDate, email, status } = user
      { profile, referrerUsername, referralUsed, globalFlags } = this

      fakeClient = connection: delegate: this

      Payment.subscriptions fakeClient, {}, (err, subscription)=>

        if err? or not subscription?
        then plan = 'free'
        else plan = subscription.planTitle

        JMachine = require "./computeproviders/machine"
        selector = 'users.id' : user.getId()

        JMachine.some selector, limit: 30, (err, machines)->

          if err? then machines = err

          callback null, {
            profile, registeredAt, lastLoginDate, email, status
            globalFlags, referrerUsername, referralUsed, plan, machines
          }


  fetchSubscriptions$: secure ({ connection:{ delegate }}, options, callback) ->
    return callback { message: 'Access denied!' }  unless @equals delegate

    [callback, options] = [options, callback]  unless callback

    options ?= {}
    { tags, status } = options

    selector = {}
    queryOptions = targetOptions: { selector }

    selector.tags = $in: tags  if tags

    selector.status = status ? $in: [
      'active'
      'past_due'
      'future'
    ]

    @fetchSubscriptions {}, queryOptions, callback

  fetchPlansAndSubscriptions: secure (client, options, callback) ->
    JPaymentPlan = require './payment/plan'

    [options, callback] = [callback, options] unless callback
    options ?= {}

    @fetchSubscriptions$ client, options, (err, subscriptions) ->
      return callback err  if err

      planCodes = (s.planCode for s in subscriptions)

      JPaymentPlan.all { planCode: $in: planCodes }, (err, plans) ->
        return callback err  if err

        callback null, { subscriptions, plans }

  fetchEmailAndStatus: secure (client, callback)->
    @fetchFromUser client, ['email', 'status'], callback

  fetchEmailFrequency: secure (client, callback)->
    @fetchFromUser client, 'emailFrequency', callback

  fetchOAuthInfo: secure (client, callback)->
    @fetchFromUser client, 'foreignAuth', callback

  fetchFromUser: secure (client, key, callback)->
    {delegate} = client.connection
    isMine     = @equals delegate
    if isMine
      @fetchUser (err, user)->
        return callback err  if err
        if Array.isArray key
          results = {}
          for k in key
            results[k] = user.getAt k

          callback null, results
        else
          callback null, user.getAt key
    else
      callback new KodingError 'Access denied'

  likeMember: permit 'like members',
    success: (client, nickname, callback)->
      JAccount.one { 'profile.nickname' : nickname }, (err, account)=>
        return callback new KodingError "An error occurred!" if err or not account

        rel = new Relationship
          targetId    : account.getId()
          targetName  : 'JAccount'
          sourceId    : @getId()
          sourceName  : 'JAccount'
          as          : 'like'

        rel.save (err)-> callback err

  setLastLoginTimezoneOffset: secure (client, options, callback) ->
    {lastLoginTimezoneOffset} = options

    return callback new KodingError "timezone offset is not set"  unless lastLoginTimezoneOffset?

    @update $set: {lastLoginTimezoneOffset}, (err) ->
      return callback new KodingError "Could not update last login timezone offset" if err
      callback null

  expireSubscription: secure ({connection}, callback) ->
    if KONFIG.environment is "production"
      return callback new KodingError "permission denied"

    {expireSubscription} = require "./socialapi/requests"
    expireSubscription connection.delegate.getId(), callback


  ###*
   * Fetches one time access token from active session
   * If accesstoken used before (not exists) it creates
   * and returns new one while updating the session.
   *
   * @param  {Function(err, token)} callback
  ###
  fetchOtaToken: secure (client, callback) ->

    { sessionToken } = client

    errorCallback = ->
      callback new KodingError 'Invalid session'

    unless sessionToken
      return errorCallback()

    JSession         = require './session'
    { v4: createId } = require 'node-uuid'

    JSession.one {clientId: sessionToken}, (err, session) ->

      if err or not session
        return errorCallback()

      if session.otaToken?
        callback null, session.otaToken
      else
        otaToken = createId()
        session.update $set: {otaToken}, (err)->
          if err then errorCallback()
          else callback null, otaToken
