class IDE.FileFinder extends KDCustomHTMLView

  constructor: (options = {}, data) ->

    options.cssClass = 'file-finder'

    super options, data

    @addSubView @input = new KDInputView
      type         : 'text'
      placeholder  : 'Type file name to search'
      callback     : @bound 'search'
      keyup        :
        'esc'      : @bound 'destroy'
        'enter'    : @bound 'handleEnterKey'
        'down'     : => @handleNavigation 'down'
        'up'       : => @handleNavigation 'up'

    @input.on 'keyup', KD.utils.debounce 300, @bound 'handleKeyUp'

    @addSubView new KDCustomHTMLView cssClass: 'icon'
    @addSubView @content = new KDCustomHTMLView

    @appendToDomBody()

    KD.getSingleton('windowController').addLayer this
    @on 'ReceivedClickElsewhere', @bound 'destroy'

  search: (text) ->
    return @cancelSearch()  if text is ''

    vmController    = KD.getSingleton 'vmController'
    rootPath        = "/home/#{KD.nick()}/"
    @isSearchActive = yes
    @lastTerm       = text

    vmController.run "find #{rootPath} -type f -iname *#{text}* -not -path '*/.*'", (err, res) =>
      return @showWarning 'An error occured, please try again.' if err
      return @showWarning 'No files found'  unless res.stdout

      @cancelSearch()

      files = res.stdout.split '\n'
      items = []

      items.push path: file  for file in files when file

      listOptions        =
        itemChildClass   : IDE.FileFinderItem
        itemChildOptions :
          cssClass       : 'file-item'
        scrollView       : no
        keyNav           : yes
        wrapper          : no

      @listController = new KDListViewController listOptions, { items }
      @listController.getView().on 'ItemWasAdded', (item) =>
        item.once 'viewAppended', =>
          item.child.on 'FileNeedsToBeOpened', @bound 'openFile'

      @content.addSubView @listController.getView()

  handleNavigation: (direction) ->
    lc = @listController
    return  unless lc

    if direction is 'down' then lc.selectNextItem() else lc.selectPrevItem()

    [item] = lc.selectedItems
    item?.getElement().scrollIntoViewIfNeeded()

  handleKeyUp: (event) ->
    listenedKeys  = [13, 27, 38, 40]
    isListenedKey = listenedKeys.indexOf(event.which) > -1
    inputValue    = @input.getValue()
    isSameText    = inputValue is @lastTerm

    return  if isListenedKey or isSameText

    @search inputValue

  handleEnterKey: ->
    value = @input.getValue()

    if not @listController or @lastTerm isnt value
      @search value
    else
      [selected] = @listController.selectedItems
      @openFile selected.getData().path  if selected

  cancelSearch: ->
    @content.destroySubViews()
    @listController?.destroy()
    @isSearchActive = no

  openFile: (path) ->
    file = FSHelper.createFileFromPath path

    file.fetchContents (err, contents) =>
      return warn err  if err # TODO: Handle error
      @destroy()
      KD.getSingleton('appManager').tell 'IDE', 'openFile', file, contents

  showWarning: (text) ->
    @content.destroySubViews()
    @content.addSubView new KDCustomHTMLView
      cssClass  : 'warning'
      partial   : text

  viewAppended: ->
    super
    @input.setFocus()
