{Range,Point,CompositeDisposable} = require 'atom'
http = require 'http'
{filter} = require 'fuzzaldrin'
CP = require 'child_process'
fs = require 'fs'

module.exports = ZoteroBibtexAutocomplete =
  activate: (state) ->

  autocompleteProvider: () ->
    selector: '.source.gfm'
    getSuggestions: ({editor, bufferPosition}) =>
      filePath=editor.getBuffer().getPath()
      rng = editor.bufferRangeForBufferRow bufferPosition.row
      rng=new Range rng.start, bufferPosition

      txt = editor.getTextInRange(rng)
      match =
        txt.match /@([^@\];,]+)$/
      prefix = match?[1]
      return [] if not prefix? or prefix?.length<2
      url=null
      editor.scanInBufferRange /^bibliography:\s*(https?:\/\/.*)$/m,
        editor.getBuffer().getRange(),
        ({match}) ->
          url=match[1]
      url = 'http://localhost:23119/better-bibtex/library?library.betterbiblatex'
      new Promise (resolve) =>
        http.get(url, (res) =>
          str = ''

          res.on 'data', (chunk) ->
            str += chunk.toString()

          res.on 'end', =>
            fs.writeFile '/tmp/biblio.bib', str, =>
              CP.exec 'pandoc-citeproc -j /tmp/biblio.bib', {encoding: 'utf-8'}, (e, sto, ste) =>
                console.warn ste
                resolve @getBibSuggestions sto, prefix
        ).on('error', (e) ->
          console.log("Got error: " + e.message)
          resolve []
        ).end()
    dispose: ->
      # Your dispose logic here

  getBibSuggestions: (str, prefix) ->
    json=JSON.parse(str)
    candidates = json.map (c) ->
      c.searchKey="#{c.id}: #{c.title}"
      for a,v of c.entryTags
        c.searchKey+=' '+v if v? and a in ['author','title','date']
      c
    s=filter candidates, prefix,
      key:'searchKey'
    return s.map (c) ->
      text: '@'+c.id
      replacementPrefix: '@'+prefix
      description: c.title

  deactivate: ->
