require 'date'

raise unless ARGV.size == 5
url, title, date, author, blog_name = ARGV

date = Date.parse(date)

file_title = title.downcase.gsub(/[^a-zA-Z0-9]/, '-')
file = "_posts/#{date.strftime("%Y-%m-%d")}-#{file_title}.md"
p file

data = <<YAML
---
layout: post
title: "#{title}"
author: "#{author}"
original_post: #{url}
blog_name: "#{blog_name}"
---
YAML

File.write(file, data)
