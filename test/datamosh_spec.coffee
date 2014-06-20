mocha = require 'mocha'
assert = require('chai').assert

fs = require 'fs'
path = require 'path'
spawn = require('child_process').spawn

FILES_DIR = path.join __dirname, 'files'
OUTPUT_DIR = path.join FILES_DIR, 'output'
TMP_DIR = 'tmp'

AviGlitch = require 'lib/aviglitch'
Base = require 'lib/aviglitch/base'
Frames = require 'lib/aviglitch/frames'
Frame = require 'lib/aviglitch/frame'


describe 'datamosh cli', ->

    before ->
        fs.mkdirSync OUTPUT_DIR unless fs.existsSync OUTPUT_DIR
        fs.mkdirSync TMP_DIR unless fs.existsSync TMP_DIR
        @in = path.join FILES_DIR, 'sample.avi'
        @out = path.join OUTPUT_DIR, 'out.avi'
        datamosh = path.resolve __dirname, '..', 'bin/datamosh'

    beforeEach (done) ->
        a = AviGlitch.open @in
        keys = 0
        a.frames.each (f) ->
            keys += 1 if f.is_keyframe()
        @total = a.frames.length()
        a.close -> done()

    afterEach (done) ->
        fs.readdir OUTPUT_DIR, (err, files) ->
            throw err if err
            fs.unlinkSync path.join(OUTPUT_DIR, file) for file in files
            done()

    after (done) ->
        fs.rmdirSync OUTPUT_DIR
        fs.readdir TMP_DIR, (err, files) ->
            throw err if err
            fs.unlinkSync path.join(TMP_DIR, file) for file in files
            fs.rmdirSync TMP_DIR
            done()

    it 'should work correctly without options', (done) ->
        d1  = spawn('coffee', ['bin/datamosh', @in, '-o', @out])
        d1.on 'exit', =>
            o = AviGlitch.open @out
            assert.equal o.frames.length(), @total
            assert o.frames.first().is_keyframe()
            assert o.has_keyframe()
            o.close()
            assert Base.surely_formatted?(@out, true)
            done()

    it 'should work correctly w/ --all', (done) ->
        d2  = spawn('coffee', ['bin/datamosh', @in, '-o', @out, '-a'])
        d2.stderr.pipe process.stderr
        d2.on 'exit', =>
            o = AviGlitch.open @out
            assert.equal o.frames.length(), @total
            assert.isFalse o.frames.first().is_keyframe()
            assert.isFalse o.has_keyframe()
            o.close()
            assert Base.surely_formatted?(@out, true)
            done()

    it 'should concat frames w/ multiple input files', (done) ->
        d3  = spawn('coffee', ['bin/datamosh', '-o', @out, @in, @in, @in])
        d3.stderr.pipe process.stderr
        d3.on 'exit', =>
            o = AviGlitch.open @out
            assert.equal o.frames.length(), @total * 3
            assert o.frames.first().is_keyframe()
            o.close()
            assert Base.surely_formatted?(@out, true)
            done()

    it 'should not glitch the video w/ --fake', (done) ->
        d4  = spawn('coffee', ['bin/datamosh', '-o', @out, @in, '--fake'])
        d4.stderr.pipe process.stderr
        d4.on 'exit', =>
            o = AviGlitch.open @out
            assert.isFalse o.has_keyframe()
            o.close()
            done()
