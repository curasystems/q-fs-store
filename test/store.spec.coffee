qStore = require('../lib/store')

fs = require('fs')
wrench = require('wrench')
_ = require('underscore')
streamBuffers = require('stream-buffers')

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

    describe 'finding packages', ->

        beforeEach (done)->
            storeTestPackage '1.0.0', ->
                storeTestPackage '1.1.0', ->
                    storeTestPackage '2.1.0', done

        it 'can find the all matching versions of a package', (done)->
            s.findMatching TEST_PACKAGE_INFO.name, '~1', (err,matchingVersions)->
                matchingVersions.length.should.equal 2
                matchingVersions.should.contain '1.0.0'
                matchingVersions.should.contain '1.1.0'
                done()

        it 'can find the highest matching version of a package', (done)->
            s.findHighest TEST_PACKAGE_INFO.name, '~1', (err,highest)->
                highest.should.equal '1.1.0'
                done()

        it 'if not match exists raise an error', (done)->
            s.findHighest TEST_PACKAGE_INFO.name, '>2.2', (err,highest)->
                err.should.be.instanceof( qStore.NoMatchingPackage )
                done()

    describe 'downloading packages', ->
        
        beforeEach (done)->
            storeTestPackage '1.3.4', ->
               done()

        it 'is possible by asking for uid', (done)->
            retrievePackage TEST_PACKAGE_INFO.uid, done

        it 'returns the data as stored', (done)->
            retrievePackage TEST_PACKAGE_INFO.uid, (err,data)->
                data.should.deep.equal( TEST_PACKAGE_INFO.data )
                done()

        it 'is also possible to ask via name and version match', (done)->
            retrievePackage TEST_PACKAGE_INFO.name + '@' + '~1.3.0', (err,data)->
                data.should.deep.equal( TEST_PACKAGE_INFO.data )
                done()

        it 'if not such match exists raise an error', (done)->
            retrievePackage TEST_PACKAGE_INFO.name + '@' + '~2.3.0', (err,data)->
                err.should.be.instanceof( qStore.NoMatchingPackage )
                done()

        retrievePackage = (identifier,callback)->
            s.readPackage identifier, (err,packageStream)->     
                return callback(err) if err

                target = new streamBuffers.WritableStreamBuffer()
                packageStream.pipe(target)
                packageStream.on 'end', ()->
                    retrievedBuffer = target.getContents()
                    callback(null,retrievedBuffer)
                    
    storeTestPackage = (version, callback)->        
        data = new Buffer([10,20,30,40,50,60])

        TEST_PACKAGE_INFO.version = version
        TEST_PACKAGE_INFO.data = data
        s.store TEST_PACKAGE_INFO, data, callback

    storeTestPackageStream = (version, callback)->        
        data = new Buffer([10,20,30,40,50,60])
        
        TEST_PACKAGE_INFO.version = version
        TEST_PACKAGE_INFO.data = data
        
        s.store TEST_PACKAGE_INFO, (err,storageStream)->
            storageStream.on 'close', callback
            storageStream.end(data)