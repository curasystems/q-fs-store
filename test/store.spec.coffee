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

    describe 'saving a packet', ->

        it 'can store packages from buffers with package info', (done)->
            saveTestPackage('1.0.0', done)        

        it 'can store packages from streams with package info', (done)->
            saveTestPackageStream('1.0.0', done)        

    describe 'listing packages', ->
        
        beforeEach (done)->
            saveTestPackage '1.0.0', done
            
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

        it 'can get package information on a specific package version', (done)->
            s.getInfo TEST_PACKAGE_INFO.name, TEST_PACKAGE_INFO.version, (err,info)->
                expect(info).to.not.be.undefined
                info.name.should.equal( TEST_PACKAGE_INFO.name )
                info.version.should.equal( TEST_PACKAGE_INFO.version )
                info.uid.should.equal( TEST_PACKAGE_INFO.uid )
                done()

        it 'can list all versions of a package', (done)->
            s.listVersions TEST_PACKAGE_INFO.name, (err,versions)->
                expect(versions).to.not.be.undefined
                versions.should.contain( TEST_PACKAGE_INFO.version )
                done()
        
    describe 'finding packages', ->

        beforeEach (done)->
            saveTestPackage '1.0.0', ->
                saveTestPackage '1.1.0-beta.1', ->
                    saveTestPackage '1.1.0', ->
                        saveTestPackage '2.1.0', done

        it 'can find the all matching versions of a package', (done)->
            s.findMatching TEST_PACKAGE_INFO.name, '~1', (err,matchingVersions)->
                matchingVersions.length.should.equal 3
                matchingVersions.should.contain '1.0.0'
                matchingVersions.should.contain '1.1.0'
                matchingVersions.should.contain '1.1.0-beta.1'
                done()

        it 'can find the highest available version compared to a list', (done)->
            s.findHighest TEST_PACKAGE_INFO.name, ['1.0.0','1.1.0'], (err, matchingVersion)->
                matchingVersion.should.equal '1.1.0'
                done()                

        it 'can find the highest matching version of a package', (done)->
            s.findHighest TEST_PACKAGE_INFO.name, '~1', (err,highest)->
                highest.should.equal '1.1.0'
                done()

        it 'if not match exists raise an error', (done)->
            s.findHighest TEST_PACKAGE_INFO.name, '>2.2', (err,highest)->
                err.should.be.instanceof( qStore.NoMatchingPackage )
                done()

        it 'offers a way to simply retrieve the highest version in an array of versions', ->
            version = s.highestVersionOf ['1.1.0','1.1.0-beta1','1.0.0']
            version.should.equal('1.1.0')

        it 'offers a way to create a list of versions with the highest version removed', ->
            version = s.removeHighestVersion ['1.1.0','1.1.0-beta1','1.0.0', '3.2.0']
            version.should.not.include('3.2.0')            

        it 'can find the second to highest version contained in two lists', ->
            version = s.findSecondHighestMatchingVersion ['1.0.0','1.1.0-beta1','1.1.0','2.0.0','3.2.0'],['1.0.4','2.0.0','3.2.0']
            version.should.equal '2.0.0'
            

    describe 'retrieving packages', ->
        
        beforeEach (done)->
            saveTestPackage '1.3.4', ->
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
                    
    saveTestPackage = (version, callback)->        
        data = new Buffer([10,20,30,40,50,60])

        TEST_PACKAGE_INFO.version = version
        TEST_PACKAGE_INFO.data = data
        s.writePackage TEST_PACKAGE_INFO, data, callback

    saveTestPackageStream = (version, callback)->        
        data = new Buffer([10,20,30,40,50,60])
        
        TEST_PACKAGE_INFO.version = version
        TEST_PACKAGE_INFO.data = data
        
        s.writePackage TEST_PACKAGE_INFO, (err,storageStream)->
            storageStream.on 'close', callback
            storageStream.end(data)