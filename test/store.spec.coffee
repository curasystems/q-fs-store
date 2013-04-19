qStore = require('../lib/store')

fs = require('fs')
streamBuffers = require('stream-buffers')
wrench = require('wrench')
_ = require('underscore')

{expect} = require('./testing')

describe 'starting it', ->

    s = null

    TEST_OPTIONS =
        path: "#{__dirname}/store"
    TEST_PACKAGE_INFO =
        uid: 'b74ed98ef279f61233bad0d4b34c1488f8525f27'
        name: 'test'
        version: null
        description: 'test description'

    beforeEach ()->
        wrench.rmdirSyncRecursive TEST_OPTIONS.path if fs.existsSync TEST_OPTIONS.path
        s = qStore(TEST_OPTIONS)
      
    it 'can be built', ->
        expect(s).to.not.be.undefined
        expect(s).to.not.be.null

    describe 'storing a packet', ->

        it 'can store packages from buffers with package info', (done)->
            storeTestPackage('1.0.0', done)        

        it 'can store packages from streams with package info', (done)->
            storeTestPackageStream('1.0.0', done)        

    describe 'listing packages', ->
        
        beforeEach (done)->
            storeTestPackage '1.0.0', done
            
        it 'can list all stored packages by uid', (done)->
            s.listRaw (err,packageList)->
                packageList.should.contain TEST_PACKAGE_INFO.uid
                done()

        it 'can list all stored packages infos', (done)->
            s.listAll (err,list)->
                expect(list).to.not.be.undefined
                list[0].name.should.equal( TEST_PACKAGE_INFO.name )
                list[0].version.should.equal( TEST_PACKAGE_INFO.version )
                done()

          it 'can list all versions of a package', (done)->
            s.listVersions TEST_PACKAGE_INFO.name, (err,versions)->
                expect(versions).to.not.be.undefined
                versions.should.contain( TEST_PACKAGE_INFO.version )
                done()

    #describe 'find '
    #   it 'can find the hig'

    storeTestPackage = (version, callback)->        
        data = new Buffer([10,20,30,40,50,60])

        TEST_PACKAGE_INFO.version = version
        s.store TEST_PACKAGE_INFO, data, callback

    storeTestPackageStream = (version, callback)->        
        data = new Buffer([10,20,30,40,50,60])
        
        stream = new streamBuffers.ReadableStreamBuffer()
        stream.put(data)

        TEST_PACKAGE_INFO.version = version
        s.store TEST_PACKAGE_INFO, stream, callback