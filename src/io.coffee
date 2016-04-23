fs   = require 'fs'
path = require 'path'

class IO
    read_formats =
        V: (buf) -> buf.readUInt32LE(0)
        a: (buf) -> buf.toString()

    write_formats =
        a: (buf, data) -> buf.write(data)
        V: (buf, data) -> buf.writeUInt32LE(data, 0)

    size_formats =
        a: 1
        V: 4

    constructor: (@path, flags, @pos = 0, callback) ->
        @is_io = true
        flags = if flags? then flags else 'w+'
        @fd = fs.openSync @fullpath(), flags
        callback() if callback?

    @tmp_id = 0
    @removeTmp = -> fs.rmdirSync 'tmp'
    @temp = (flags, callback) ->
        unless @has_tmp
            @has_tmp = true
            fs.mkdirSync 'tmp' unless fs.existsSync 'tmp'
            process.removeAllListeners()
            process.removeAllListeners()
            # process.addListener 'exit', @removeTmp
            # process.addListener 'error', @removeTmp

        tmppath = path.resolve 'tmp', @tmp_id.toString()
        @tmp_id += 1
        io = new IO tmppath, 'w+', 0, callback

    size: -> fs.fstatSync(@fd)["size"]
    seek: (@pos) -> @pos
    seedEnd: -> @seek @size()
    move: (d) -> @pos += d

    read: (size, format) ->

        if @pos + size > @size()
            size = @size() - @pos
        if size <= 0
            return new Buffer(0)

        buf = new Buffer size
        @pos += fs.readSync(@fd, buf, 0, size, @pos)

        if format?
            return read_formats[format](buf)
        else
            return buf

    write: (data, format, num_data = 1) ->
        if format?
            buf = new Buffer size_formats[format] * num_data
            write_formats[format](buf, data)
        else
            buf = data
            size = buf.length
        throw new TypeError 'IO#write requires the data format with a buffer' if !Buffer.isBuffer(data) and !format?
        @pos += fs.writeSync @fd, buf, 0, buf.length, @pos

    close: (callback) ->
        fs.close @fd, (err) ->
            throw err if err
            callback() if callback?

    closeSync: ->
        fs.closeSync @fd

    truncate: (size) ->
        fs.ftruncateSync @fd, size

    fullpath: ->
        path.resolve __dirname, '../../', @path

    ##
    # Pack data to a binary string.
    @pack = (format, data) ->
        bufs = []
        for i, f of format
            buf = new Buffer size_formats[f]
            write_formats[f](buf, data[i])
            bufs.push buf
        return Buffer.concat bufs

module.exports = IO
