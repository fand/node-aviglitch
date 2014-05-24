#!/usr/bin/env coffee
# Generate datamoshing

fs = require 'fs'
argv = require('optimist').argv
AviGlitch = require '../lib/aviglitch'

output = './coffee.avi'
all = false
fake = false

# opts = OptionParser.new do |opts|
#   opts.banner = "datamosh - AviGlitch's datamoshing video generator."
#   opts.define_head "Usage: #{File.basename($0)} [options] file [file2 ...]"
#   opts.separator "Options:"
#   opts.on("-o", "--output [OUTPUT]",
#     "Output the video to OUTPUT (./out.avi by default)") do |f|
#     output = f
#   end
#   opts.on("-a", "--all",
#     "Remove all keyframes (It remains a first keyframe by default)") do
#     all = true
#   end
#   opts.on("--fake", "Remains all keyframes as full pixel included deltaframe") do
#     fake = true
#     if all
#       warn "The --fake option cannot use with -a/--all option.\n"
#       exit
#     end
#   end
#   opts.on_tail("-h", "--help", "Show this message") do
#     puts opts
#     exit
#   end
# end

input = argv._
if input.length == 0
    console.log argv
    process.exit()
else
    for file in input
        if !fs.existsSync(file) || fs.lstatSync(file).isDirectory()
            opts.banner = "#{file}: No such file.\n\n"
            console.log argv
            process.exit 1

a = AviGlitch.open input.shift()

unless fake
    a.glitch_with_index 'keyframe', (frame, i) ->
        if (!all && i == 0) then frame.data else undefined # keep the first frame

# if !all && !fake
#     a.mutate_keyframes_into_deltaframes([1...a.frames.length])
# else
#     a.mutate_keyframes_into_deltaframes()

# input.each do |file|
#   b = AviGlitch.open file
#   unless fake
#     b.glitch :keyframe do |frame|
#       ""
#     end
#   end
#   b.mutate_keyframes_into_deltaframes!
#   a.frames.concat b.frames
# end

a.output output
process.exit()
