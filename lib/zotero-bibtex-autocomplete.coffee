ZoteroBibtexAutocompleteView = require './zotero-bibtex-autocomplete-view'
{Range,Point,CompositeDisposable} = require 'atom'
http = require 'http'
bib = require 'zotero-bibtex-parse'

module.exports = ZoteroBibtexAutocomplete =
  zoteroBibtexAutocompleteView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    provider =
      selector: '.source.gfm' # This provider will be run on JavaScript and Coffee files
      requestHandler: (options) ->
        rng=new Range options.editor.getBuffer().getFirstPosition(),options.position
        options.prefix=""
        options.editor.backwardsScanInBufferRange /\[\@([^\]]+)$/,rng,(match)->
          options.prefix=match.match[1]
        console.log(options.prefix)
        return [] if options.prefix.length<2
        new Promise (resolve) ->
          http.get("http://localhost:23119/better-bibtex/library?library.biblatex", (res) ->
              str = '';

              #another chunk of data has been recieved, so append it to `str`
              res.on('data', (chunk) ->
                str += chunk;
              );

              #the whole res has been recieved, so we just print it out here
              res.on('end', ->
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
    @registration = atom.services.provide('autocomplete.provider', '1.0.0', {provider:provider})

  deactivate: ->
    @registration.dispose()
