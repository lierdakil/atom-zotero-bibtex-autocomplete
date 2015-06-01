{Range,Point,CompositeDisposable} = require 'atom'
http = require 'http'
bib = require 'zotero-bibtex-parse'
{filter} = require 'fuzzaldrin'

module.exports = ZoteroBibtexAutocomplete =
  activate: (state) ->

  autocompleteProvider: () ->
    selector: '.source.gfm'
    getSuggestions: ({editor, bufferPosition}) =>
      filePath=editor.getBuffer().getPath()
      rng = editor.bufferRangeForBufferRow bufferPosition.row
      rng=new Range rng.start, bufferPosition.column

      match =
        editor.getTextInRange(rng).match /[\[;]\s*\@([^\];]+)$/
      prefix = match?[1]
      return [] if not prefix? or prefix?.length<2
      url=null
      editor.scanInBufferRange /^bibliography:\s*(.*)$/m,
        editor.getBuffer().getRange(),
        ({match}) ->
          url=match[1]
      url?="http://localhost:23119/better-bibtex/library?library.biblatex"
      new Promise (resolve) =>
        http.get(url, (res) =>
          str = ''

          res.on 'data', (chunk) ->
            str += chunk

          res.on 'end', =>
            resolve @getBibSuggestions str,prefix
        ).on('error', (e) ->
          console.log("Got error: " + e.message)
          resolve []
        ).end()
    dispose: ->
      # Your dispose logic here

  getBibSuggestions: (str, prefix) ->
    json=bib.toJSON(str)
    candidates = json.map (c) ->
      c.searchKey=c.citationKey
      for a,v of c.entryTags
        c.searchKey+=' '+v if v? and a in ['author','title','date']
      c
    s=filter candidates, prefix,
      key:'searchKey'
    resolve s.map (c) ->
      text: '@'+c.citationKey
      replacementPrefix: '@'+prefix
      description: c.entryTags.author+" "+c.entryTags.title

  deactivate: ->
