{Range,Point,CompositeDisposable} = require 'atom'
http = require 'http'
bib = require 'zotero-bibtex-parse'
fs = require 'fs'
{filter} = require 'fuzzaldrin'

module.exports = ZoteroBibtexAutocomplete =
  subscriptions: null

  activate: (state) ->
    provider =
      selector: '.source.gfm'
      requestHandler: (options) ->
        filePath=options.editor.getBuffer().getPath()
        cwd_  = atom.project.getDirectories()
          .filter (d) ->
            d.contains(filePath)
        rng=new Range options.editor.getBuffer().getFirstPosition(),
                      options.position
        match =
          options.editor.getTextInRange(rng).match /\[\@([^\]]+)$/
        prefix = match?[1]
        return [] if not prefix? or prefix?.length<2
        url=null
        bibliography=null
        options.editor.scanInBufferRange /^bibliography-url:\s*(.*)$/m,
          options.editor.getBuffer().getRange(),
          ({match}) ->
            url=match[1]
        url?="http://localhost:23119/better-bibtex/library?library.biblatex"
        options.editor.scanInBufferRange /^bibliography:\s*(.*\.biblatex)$/m,
          options.editor.getBuffer().getRange(),
          ({match}) ->
            bibliography=match[1]
            bibliography=cwd_[0].resolve(bibliography) if bibliography?
        new Promise (resolve) ->
          http.get(url, (res) ->
            str = ''

            res.on 'data', (chunk) ->
              str += chunk

            res.on 'end', ->
              fs.writeFileSync(bibliography,str) if bibliography?
              json=bib.toJSON(str)
              candidates = json.map (c) ->
                c.searchKey=c.citationKey
                for a,v of c.entryTags
                  c.searchKey+=' '+v if v? and a in ['author','title','date']
                c
              s=filter candidates, prefix,
                key:'searchKey'
                maxResults:10
              resolve s.map (c) ->
                word: '[@'+c.citationKey+']'
                prefix: '[@'+prefix
                label: c.entryTags.author+" "+c.entryTags.title
          ).on('error', (e) ->
            console.log("Got error: " + e.message)
            resolve []
          ).end();
      dispose: ->
        # Your dispose logic here
    @registration = atom.services.provide 'autocomplete.provider', '1.0.0',
      provider:provider

  deactivate: ->
    @registration.dispose()
