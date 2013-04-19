path = require('path')

_ = require('underscore')
mkdirp = require('mkdirp')
glob = require('glob')

module.exports = (options)->
    return new FileSystemPackageStore(options)

class FileSystemPackageStore

    DEFAULT_OPTIONS=
        path: "#{process.cwd()}/store"

    constructor: (options)->
        @options = _.defaults options, DEFAULT_OPTIONS

    store: (info, data, callback)->
        packageStoragePath = @_buildStoragePathFromInfo(info)
        
        @_createDirectoryForFile packageStoragePath, (err)=>
            return callback(err) if err

            if Buffer.isBuffer(data)
                return @_storeBuffer(data, packageStoragePath, callback)

            callback('dont understand data')

    _buildStoragePathFromInfo: (info)->
        relativePath = path.join( 'objects', info.uid.substr(0,2), info.uid + '.pkg' )
        fullPath = path.join(@options.path, relativePath)

    _createDirectoryForFile: (packagePath, callback)->
        mkdirp path.dirname(packagePath), callback

    _storeBuffer: (buffer, targetPath, callback)->
        fs.writeFile targetPath, buffer, callback

    listRaw: (callback)->
        glob '**/*.pkg', cwd:@options.path, (err,packages)->
            return callback(err) if err

            packages = (path.basename(f, '.pkg') for f in packages)
            callback(null, packages)

    