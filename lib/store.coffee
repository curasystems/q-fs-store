path = require('path')
fs = require('fs')
stream = require('stream')

_ = require('underscore')
mkdirp = require('mkdirp')
glob = require('glob')
semver = require('semver')

module.exports = (options)->
    return new FileSystemPackageStore(options)

module.exports.InvalidVersionError = class InvalidVersionError extends Error
    constructor: (@details)->super(@details)

module.exports.NoMatchingPackage = class NoMatchingPackage extends Error
    constructor: (@details)->super(@details)

module.exports.MissingPackageError = class MissingPackageError extends Error
    constructor: (@details)->super(@details)

class StorageStream extends stream.Transform

    constructor: (@store, @packageInfo, @packageStoragePath)->
        super()

    _transform: (chunk,encoding,callback)->
        @push(chunk)
        callback()

    _flush: (callback)->
        @store._storeInfo @packageInfo, @packageStoragePath, (err)=>
            return callback(err) if err
            @push(null)
            callback(null)

    emitCloseEvent: ()->
        @emit 'close'
        
class FileSystemPackageStore

    DEFAULT_OPTIONS=
        path: "#{process.cwd()}/store"

    constructor: (options)->
        @options = _.defaults options, DEFAULT_OPTIONS

        @refDirectory = path.join(@options.path, 'refs')
        @objectDirectory = path.join(@options.path, 'objects')
        

    writePackage: (info, data, callback)->

        if _.isFunction(data)
            callback = data
            data = null

        packageStoragePath = @_buildStoragePathFromInfo(info)
        
        @_createDirectoryForFile packageStoragePath, (err)=>
            return callback(err) if err

            targetStream = fs.createWriteStream packageStoragePath

            storageStream = new StorageStream(this,info,packageStoragePath)
            storageStream.pipe(targetStream)
            targetStream.on 'close', ->storageStream.emitCloseEvent()
                
            if Buffer.isBuffer(data)
                writeError = null
                storageStream.end data
                targetStream.on 'error', (error)->
                    writeError = error
                targetStream.on 'close', ()->
                    callback(writeError)
            else
                callback(null,storageStream)                    

    _buildStoragePathFromInfo: (info)->
        return @_buildStoragePathFromUid(info.uid)

    _buildStoragePathFromUid: (uid)->
        relativePath = path.join( uid.substr(0,2), uid + '.pkg' )
        fullPath = path.join(@objectDirectory, relativePath)

    _createDirectoryForFile: (filePath, callback)->
        mkdirp path.dirname(filePath), callback

    _storeInfo: (info, packageStoragePath, callback)->

        return callback(new InvalidVersionError(info.version)) unless semver.valid(info.version)

        refPath = @_buildRefPath( info.name, info.version )
    
        @_createDirectoryForFile refPath, (err)=>
            return callback(err) if err

            packageReference = _.clone(info)
            packageReference.path = path.relative(@objectDirectory, packageStoragePath)

            fs.writeFile refPath, JSON.stringify(packageReference, null,' '), callback

    _buildRefPath: (name,version)->
        path.join( @refDirectory, name, version + '.json' )
    
    listRaw: (callback)->
        glob '**/*.pkg', cwd:@objectDirectory, (err,packages)->
            return callback(err) if err

            packages = (path.basename(f, '.pkg') for f in packages)
            callback(null, packages)

    listAll: (callback)->

        glob '**/*.json', cwd:@refDirectory, (err,refs)=>
            return callback(err) if err

            packageInfos = (@_readPackageInfoFromPath(infoPath) for infoPath in refs)
            callback(null, packageInfos)

    _readPackageInfoFromPath: (infoPath)->        
        [name, jsonVersion] = infoPath.split('/')
        version = path.basename(jsonVersion, '.json' )
        return name:name, version:version

    listVersions: (packageName, callback)->
        packageRefsDirectory = path.join(@refDirectory, packageName)

        glob '**/*.json', cwd:packageRefsDirectory, (err,refs)=>
            return callback(err) if err

            versions = (path.basename(infoPath, '.json') for infoPath in refs)
            callback(null, versions)

    findMatching: (packageName, versionMatch, callback)->
        @listVersions packageName, (err,versions)->
            return callback(err) if err

            matchingVersions = _.filter versions, (v)->semver.satisfies(v,versionMatch)

            callback(null,matchingVersions)    

    findHighest: (packageName, versionMatch, callback)->
        @findMatching packageName, versionMatch, (err,versions)->
            return callback(err) if err

            highestMatch = semver.maxSatisfying versions, versionMatch

            if not highestMatch
                return callback(new NoMatchingPackage(packageName+'@'+versionMatch))
            else
                callback(null,highestMatch)

    getPackageStoragePath: (packageIdentifier, callback)->

        if packageIdentifier.indexOf('@')>0
            [name,versionMatch] = packageIdentifier.split('@')
            @findHighest name, versionMatch, (err,version)=>
                return callback(err) if err
                @_lookupPackagePath name, version, callback
        else
            packagePath = @_buildStoragePathFromUid(packageIdentifier)
            @_lookupPackagePath name, version, callback

    readPackage: (packageIdentifier, callback)->

        @getPackageStoragePath packageIdentifier, (err,packagePath)=>
            return callback(err) if err
            @_returnPackage packagePath, callback        
        
    _lookupPackagePath: (name,version,callback)->
        refPath = @_buildRefPath(name,version)
        fs.readFile refPath, encoding:'utf8', (err,data)=>
            return callback(err) if err
            
            refInfo = JSON.parse(data)
            packagePath = path.join(@objectDirectory, refInfo.path)
            callback(null,packagePath)

    _returnPackage: (packagePath, callback)->
        fs.exists packagePath, (exists)=>
            if(exists)
                return callback(null,fs.createReadStream(packagePath))
            else
                return callback(new MissingPackageError(packagePath))
            