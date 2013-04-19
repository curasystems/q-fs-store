qStore = require('../lib/store')

fs = require('fs')
wrench = require('wrench')

{expect} = require('./testing')

describe 'starting it', ->

    s = null
    TEST_OPTIONS=
        path: "#{__dirname}/store"

    beforeEach ()->
        wrench.rmdirSyncRecursive TEST_OPTIONS.path if fs.existsSync TEST_OPTIONS.path
        s = qStore(TEST_OPTIONS)
      
    it 'can be built', ->
        expect(s).to.not.be.undefined
        expect(s).to.not.be.null

    it 'can store packages from buffers with package info', (done)->
        storeTestPackage('1.0', done)        

    it 'can list all stored packages by uid', (done)->
        storeTestPackage '1.0', ()-> 
            s.listRaw (err,packageList)->
                expect(packageList).should.not.be.undefined
                console.log packageList
                done()


    storeTestPackage = (version, callback)->
        info = 
            uid: 'b74ed98ef279f61233bad0d4b34c1488f8525f27'
            name: 'test'
            version: version
            description: 'test description'

        data = new Buffer([10,20,30,40,50,60])

        s.store info, data, callback