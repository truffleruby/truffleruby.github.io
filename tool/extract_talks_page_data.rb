require 'yaml'

data = File.readlines("talks.md", chomp: true).slice_before(/^## /).to_a
data.shift
data = data.map { |lines|
  pp(lines) unless lines.size == 4
  title = lines[0][/^## (.+)/, 1] or raise lines[0]
  iframe = lines[2]
  video_id = %r{https://www.youtube-nocookie\.com/embed/([\w-]+)\?si=}.match(iframe)[1] or raise iframe
  [title, video_id]
}

File.write('tool/talks_data.yml', YAML.dump(data))
