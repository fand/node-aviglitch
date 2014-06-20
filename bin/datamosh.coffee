#!/usr/bin/env coffee
# Generate datamoshing

fs = require 'fs'
path = require 'path'
argv = require('commander')
AviGlitch = require '../lib/aviglitch'

output = 'out.avi'
all = false
fake = false


command = require('commander')
command
    .usage('[options] <file ...>')
    .version('0.0.0')
    .option('-o, --output [OUTPUT]', 'output the video to OUTPUT (./out.avi by default)', (val) ->
        output = val
    )
    .option('-a, --all', 'remove all keyframes (It remains a first keyframe by default)', ->
        all = true
    )
    .option('-f, --fake', 'remains all keyframes as full pixel included deltaframe', ->
        if all
            console.error "The --fake option cannot use with -a/--all option.\n"
            process.exit(-1)
        fake = true
    )
    .parse(process.argv)

# Check input files.
input = command.args
if input.length < 1
    command.help()
    process.exit()
for file in input
    if !fs.existsSync(file) || fs.lstatSync(file).isDirectory()
        console.error "#{file}: No such file.\n\n"
        process.exit 1

a = AviGlitch.open input.shift()

unless fake
    frames = 0
    a.glitch_with_index 'keyframe', (frame, i) ->
        frames++
        if (not all) and i == 0
            frame.data
        else
            new Buffer(0) # keep the first frame

unless all or fake
    a.mutate_keyframes_into_deltaframes([1...a.frames.length()])
else
    a.mutate_keyframes_into_deltaframes()

for file in input
    b = AviGlitch.open file
    unless fake
        b.glitch 'keyframe', -> new Buffer(0)

    b.mutate_keyframes_into_deltaframes()
    a.frames.concat b.frames

dst = path.resolve __dirname, '..', output
a.output dst, null, ->
    process.exit()
