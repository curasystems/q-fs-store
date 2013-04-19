path = require('path')

_ = require('underscore')
mkdirp = require('mkdirp')
glob = require('glob')
semver = require('semver')

module.exports.InvalidVersionError = class InvalidVersionError extends Error
    constructor: (@details)->super(@details)


module.exports = (options)->
    return new FileSystemPackageStore(options)

class FileSystemPackageStore

    DEFAULT_OPTIONS=
        path: "#{process.cwd()}/store"

    constructor: (options)->
        @options = _.defaults options, DEFAULT_OPTIONS

        @refDirectory = path.join(@options.path, 'refs')
        @objectDirectory = path.join(@options.path, 'objects')
        

    store: (info, data, callback)->
        packageStoragePath = @_buildStoragePathFromInfo(info)
        
        @_createDirectoryForFile packageStoragePath, (err)=>
            return callback(err) if err

            if Buffer.isBuffer(data)
                @_storeBuffer data, packageStoragePath, (err)=>
                    return callback(err) if err
                    @_storeInfo info, packageStoragePath, callback
            else
                @_storeStream data, packageStoragePath,(err)=>
                    return callback(err) if err
                    @_storeInfo info, packageStoragePath, callback                

    _buildStoragePathFromInfo: (info)->
        relativePath = path.join( info.uid.substr(0,2), info.uid + '.pkg' )
        fullPath = path.join(@objectDirectory, relativePath)

    _createDirectoryForFile: (filePath, callback)->
        mkdirp path.dirname(filePath), callback

    _storeBuffer: (buffer, targetPath, callback)->
        fs.writeFile targetPath, buffer, callback

    _storeStream: (stream, targetPath, callback)->
        writeError = null

        target = fs.createWriteStream targetPath
        stream.pipe(target)
        target.on 'error', (error)->
            writeError = error
        target.on 'close', ()->callback(writeError)

    _storeInfo: (info, packageStoragePath, callback)->

        return callback(new InvalidVersionError(info.version)) unless semver.valid(info.version)

        refPath = path.join( @refDirectory, info.name, info.version + '.json' )
    
        @_createDirectoryForFile refPath, (err)=>
            return callback(err) if err

            packageReference = _.clone(info)
            packageReference.path = path.relative(@options.path, packageStoragePath)

            fs.writeFile refPath, JSON.stringify(packageReference, null,' '), callback

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

        glob '**/*.json', cwd:@refDirectory, (err,refs)=>
            return callback(err) if err

            versions = (path.basename(infoPath, '.json') for infoPath in refs)
            callback(null, versions)




    