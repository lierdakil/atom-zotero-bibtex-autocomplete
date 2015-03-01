{Range,Point,CompositeDisposable} = require 'atom'
http = require 'http'
bib = require 'zotero-bibtex-parse'
fs = require 'fs'

module.exports = ZoteroBibtexAutocomplete =
  subscriptions: null

  activate: (state) ->
    provider =
      selector: '.source.gfm'
      requestHandler: (options) ->
        rng=new Range options.editor.getBuffer().getFirstPosition(),
                      options.position
        match =
          options.editor.getTextInRange(rng).match /\[\@([^\]]+)$/
        prefix = match?[1]
        return [] if prefix?.length<2
        url=null
        bibliography=null
        options.editor.scanInBufferRange /^bibliography-url:\s*(.*)$/m,
          options.editor.getBuffer().getRange(),
          ({match}) ->
            url=match[1]
        options.editor.scanInBufferRange /^bibliography:\s*(.*\.biblatex)$/m,
          options.editor.getBuffer().getRange(),
          ({match}) ->
            bibliography=match[1]
        new Promise (resolve) ->
          http.get(url, (res) ->
            str = ''

            res.on 'data', (chunk) ->
              str += chunk

            res.on 'end', ->
              fs.writeFileSync(bibliography,str) if bibliography?
              json=bib.toJSON(str)
              s=json.filter (c) ->
                contains=c.citationKey.contains(prefix)
                for a,v of c.entryTags
                  contains=contains or v.contains(prefix)
                contains
              .map (c) ->
                word: '[@'+c.citationKey+']'
                prefix: '[@'+prefix
                label: c.entryTags.author+" "+c.entryTags.title
              resolve s
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
