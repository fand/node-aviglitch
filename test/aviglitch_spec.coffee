mocha  = require 'mocha'
assert = require('chai').assert

fs   = require 'fs'
path = require 'path'

FILES_DIR  = path.join __dirname, 'files'
OUTPUT_DIR = path.join FILES_DIR, 'output'
TMP_DIR    = 'tmp'

AviGlitch = require '../lib/aviglitch'
Base      = require '../lib/base'
Frames    = require '../lib/frames'
Frame     = require '../lib/frame'

describe 'AviGlitch', ->

    before ->
        fs.mkdirSync OUTPUT_DIR unless fs.existsSync OUTPUT_DIR
        fs.mkdirSync TMP_DIR unless fs.existsSync TMP_DIR
        @in = path.join FILES_DIR, 'sample.avi'
        @out = path.join OUTPUT_DIR, 'out.avi'

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

    it 'should raise an error against unsupported files', ->
        assert.throws  ->
            avi = AviGlitch.open __filename

    it 'should return AviGlitch::Base object through the method #open', ->
        avi = AviGlitch.open @in
        assert.instanceOf avi, Base

    it 'should save the same file when nothing is changed', ->
        avi = AviGlitch.open @in
        avi.glitch (d) ->  d
        avi.output @out

        f_in = fs.readFileSync @in
        f_out = fs.readFileSync @out
        assert f_in?, 'in file exists'
        assert f_out?, 'out file exists'
        assert.deepEqual f_in, f_out, 'nothing changed'

    it 'can glitch each keyframe', ->
        avi = AviGlitch.open @in
        n = 0
        avi.glitch 'keyframe', (kf) ->
            n += 1
            kf.slice 10

        avi.output @out
        i_size = fs.statSync(@in).size
        o_size = fs.statSync(@out).size
        assert.equal o_size, i_size - (10 * n)
        assert Base.surely_formatted(@out, true)

    it 'can glitch each keyframe with index', ->
        avi = AviGlitch.open @in

        a_size = 0
        avi.glitch 'keyframe', (f) ->
            a_size += 1
            return f

        b_size = 0
        avi.glitch_with_index 'keyframe', (kf, idx) ->
            b_size += 1
            if idx < 25
                kf.slice 10
            else
                kf

        assert.equal a_size, b_size

        avi.output @out
        i_size = fs.statSync(@in).size
        o_size = fs.statSync(@out).size
        assert.equal o_size, i_size - (10 * 25)
        assert Base.surely_formatted(@out, true)

    it 'should have some alias methods', ->
        assert.doesNotThrow =>
            avi = AviGlitch.open @in
            avi.write @out

        assert Base.surely_formatted(@out, true)

    it 'can glitch with :*frames instead of :*frame', ->
      avi = AviGlitch.open @in
      count = 0
      avi.glitch 'keyframes', (kf) =>
          count += 1
          kf

      avi.close()
      assert count > 0

    it 'should close file when output', (done) ->
        avi = AviGlitch.open @in
        avi.output @out, true, ->
            assert.throws (->
                avi.glitch (f) -> f
            ), Error
            done()

    it 'can explicit close file', (done) ->
        avi = AviGlitch.open @in
        avi.close ->
            assert.throws ->
                avi.glitch (f) -> f
            , Error
            done()

    it 'should offer one liner style coding', ->
        assert.doesNotThrow =>
            AviGlitch.open(@in).glitch('keyframe', (d) ->
                buf = new Buffer(d.length)
                buf.fill '0'
                buf
            ).output(@out)

        assert Base.surely_formatted(@out, true)

    it 'should not raise error in multiple glitches', ->
        assert.doesNotThrow =>
            avi = AviGlitch.open @in
            avi.glitch 'keyframe', (d) ->
                d.data = new Buffer(d.toString('ascii').replace(/\d/, ''))

            avi.glitch 'keyframe', (d) ->
                null

            avi.glitch 'audioframe', (d) ->
                Buffer.concat [d, d]

            avi.output @out

        assert Base.surely_formatted(@out, true)

    it 'can work with another frames instance', (done) ->
        tmp = @out + 'x.avi'
        a = AviGlitch.open @in
        a.glitch 'keyframe', (d) -> null
        a.output tmp, false
        b = AviGlitch.open @in
        c = AviGlitch.open tmp
        b.frames = c.frames
        b.output @out, false

        assert Base.surely_formatted(@out, true)
        a.close -> b.close -> c.close -> fs.unlink tmp, -> done()

    it 'should mutate keyframes into deltaframes', ->
        a = AviGlitch.open @in
        a.mutate_keyframes_into_deltaframes()
        a.output @out
        a = AviGlitch.open @out
        a.frames.each (f) ->
            assert.isFalse f.is_keyframe

        a = AviGlitch.open @in
        a.mutate_keyframes_into_deltaframes [0..50]
        a.output @out
        a = AviGlitch.open @out
        a.frames.each_with_index (f, i) ->
            if i <= 50
                assert.isFalse f.is_keyframe

    it 'should check if keyframes exist.', ->
        a = AviGlitch.open @in
        assert a.has_keyframe
        a.glitch 'keyframe', (f) -> null
        assert.isFalse a.has_keyframe

    it 'should #remove_all_keyframes!', ->
        a = AviGlitch.open @in
        assert a.has_keyframe
        a.remove_all_keyframes()
        assert.isFalse a.has_keyframe

    it 'should count same number of specific frames', ->
        a = AviGlitch.open @in
        dc1 = 0
        dc2 = 0
        a.frames.each (f) ->
            dc1 += 1 if f.is_deltaframe

        a.glitch 'deltaframe', (d) ->
            dc2 += 1
            d

        assert.equal dc1, dc2
