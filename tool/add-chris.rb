require 'date'

url = ARGV.fetch(0)

contents = `curl -s '#{url}'`
raise unless $?.success?

title = contents[/<title>(.+?)<\/title>/, 1]
puts title

h2 = contents[/<h2>(.+?)<\/h2>/, 1]
author, date = h2.split(',', 2)
puts author
date = date.strip
puts date
raise author unless author == '<a href="/">Chris Seaton</a>'
date = Date.parse(date)

file_title = title.downcase.gsub(/[^a-zA-Z0-9]/, '-')
file = "_posts/#{date.strftime("%Y-%m-%d")}-#{file_title}.md"
p file

data = <<YAML
---
layout: post
title: "#{title}"
author: "@chrisseaton"
original_post: #{url}
---
YAML

File.write(file, data)
