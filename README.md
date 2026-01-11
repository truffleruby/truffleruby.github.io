To build the website:

```bash
chruby $(cat .ruby-version)
bundle install
bundle exec jekyll serve -l
```

It is automatically rebuilt on any change and also automatically refreshes the page in the browser.
