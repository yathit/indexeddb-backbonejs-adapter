class IndexedDBBackbone.Driver.Operation
  constructor: (transaction, storeName, @data, @options = {}) ->

    @store = transaction.objectStore(storeName)

  execute: ->

class IndexedDBBackbone.Driver.AddOperation extends IndexedDBBackbone.Driver.Operation
  execute: ->
    if @store.keyPath || @store.autoIncrement
      request = @store.add(@data)
    else
      request = @store.add(@data, @options.key)

    request.onerror = @options.error
    if @options.success
      request.onsuccess = (e) => @options.success(@data)

class IndexedDBBackbone.Driver.PutOperation extends IndexedDBBackbone.Driver.Operation
  execute: ->
    # acts as insert & update
    if @store.keyPath || (@store.autoIncrement && !@options.key)
      request = @store.put(@data)
    else
      request = @store.put(@data, @options.key)

    request.onerror = @options.error
    if @options.success
      request.onsuccess = (e) => @options.success(@data)

class IndexedDBBackbone.Driver.DeleteOperation extends IndexedDBBackbone.Driver.Operation
  execute: ->
    request = @store.delete(@data)

    request.onerror = @options.error
    if @options.success
      request.onsuccess = (e) => @options.success(@data)

class IndexedDBBackbone.Driver.ClearOperation extends IndexedDBBackbone.Driver.Operation
  constructor: (transaction, storeName, options) ->
    super transaction, storeName, null, options

  execute: ->
    request = @store.clear()
    request.onsuccess = @options.success
    request.onerror = @options.error

class IndexedDBBackbone.Driver.GetOperation extends IndexedDBBackbone.Driver.Operation
  execute: ->
    if @store.keyPath && value = IndexedDBBackbone.value(@data, @store.keyPath)
      getRequest = @store.get(value)
    else if indexName = @options.indexName
      index = @store.index(indexName)
      keyPath = index.keyPath
      value = IndexedDBBackbone.value(@data, keyPath)
      getRequest = index.get(value) if value

    if (getRequest)
      getRequest.onsuccess = (e) =>
        if (e.target.result)
          @options.success?(e.target.result)
        else
          @options.error?("Not Found")
      getRequest.onerror = @options.error
    else
      @options.error?("Couldn't search: no index matches the provided model data")

class IndexedDBBackbone.Driver.Query extends IndexedDBBackbone.Driver.Operation
  constructor: (transaction, storeName, options) ->
    super transaction, storeName, null, options

  execute: ->
    options = @options
    query = options.query

    elements = []
    needsAdvancement = query._offset > 0

    source = if query._indexName then @store.index(query._indexName) else @store
    range = query.getKeyRange()

    cursorRequest = source.openCursor range, query.getDirection()

    cursorRequest.onerror = (e) ->
      options.error("cursorRequest error", e)

    cursorRequest.onsuccess = (e) ->
      if cursor = e.target.result
        if (needsAdvancement)
          needsAdvancement = false
          cursor.advance(query._offset)
        else
          elements.push(cursor.value)
          if (query._limit && elements.length >= query._limit)
            options.success?(elements) # We're done.
          else
            cursor.continue()
      else
        options.success?(elements) # We're done. No more elements.

