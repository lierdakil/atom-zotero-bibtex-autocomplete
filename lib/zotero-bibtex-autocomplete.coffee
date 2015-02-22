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
        options.prefix = match?[1]
        console.log(options.prefix)
        return [] if options.prefix?.length<2
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

            #another chunk of data has been recieved, so append it to `str`
            res.on('data', (chunk) ->
              str += chunk;
            );

            #the whole res has been recieved, so we just print it out here
            res.on('end', ->
              fs.writeFileSync(bibliography,str) if bibliography?
              json=bib.toJSON(str)
              s=json.filter (c) ->
                contains=c.citationKey.contains(options.prefix)
                for a,v of c.entryTags
                  contains=contains or v.contains(options.prefix)
                contains
              .map (c) ->
                word: '[@'+c.citationKey+']'
                prefix: '[@'+options.prefix
                label: c.entryTags.author+" "+c.entryTags.title
              resolve s
            );
          ).on('error', (e) ->
            console.log("Got error: " + e.message);
          ).end();
      dispose: ->
        # Your dispose logic here
    @registration = atom.services.provide 'autocomplete.provider', '1.0.0',
      provider:provider

  deactivate: ->
    @registration.dispose()
