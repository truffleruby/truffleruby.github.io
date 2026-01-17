require 'yaml'

data = YAML.load(File.read('tool/talks_data.yml'))

data.each { |talk|
  title, video_id = talk
  puts <<~HTML
    ## #{title}

    <a href="https://www.youtube.com/watch?v=#{video_id}" target="_blank">
      <img src="https://i.ytimg.com/vi/#{video_id}/maxresdefault.jpg"/>
    </a>

  HTML
}
