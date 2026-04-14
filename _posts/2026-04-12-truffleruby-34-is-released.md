---
layout: post
title: "TruffleRuby 34 is Released"
authors: ["@eregon", "@nirvdrum", "@andrykonchin"]
---

TruffleRuby 34 is here, bringing full Ruby 3.4 compatibility, major parsing optimizations (up to 23% faster parsing), and a new Prism-based `Ripper` implementation with 20x to 40x speedups.

The release is available [on GitHub](https://github.com/truffleruby/truffleruby/releases/tag/graal-34.0.0), in your favorite Ruby installer, and [on Maven Central](https://central.sonatype.com/artifact/dev.truffleruby/truffleruby)!

```bash
$ rbenv install truffleruby-34.0.0
$ ruby-build -d truffleruby-34.0.0 ~/.rubies
$ asdf install ruby truffleruby-34.0.0
$ mise install ruby@truffleruby-34.0.0
$ ruby-install truffleruby
$ rvm install truffleruby
```

## Compatibility With Ruby 3.4

TruffleRuby 34.0.0 is compatible with Ruby 3.4 (see [versioning](http://127.0.0.1:4000/blog/truffleruby-33-is-released#new-versioning)).

In this release, all items in the Ruby 3.4 changelog [have been implemented](https://github.com/truffleruby/truffleruby/issues/3883), including:
* `it` (`3.times { p it }`)
* better stacktraces like `from test.rb:1:in 'Object#foo'`
* new methods like `String#append_as_bytes` and `Array#fetch_values`
* Happy Eyeballs v2 support for TCP sockets
* etc

This is the first release where we have been able to implement everything in the CRuby changelog, thanks to releases being feature-based (instead of time-based), and the many contributors to this release:
![]({{ site.baseurl }}/assets/contributors-34.png)

Special mentions go to `@herwinw` for 8 PRs and `@Earlopain` for 4 PRs implementing Ruby 3.4 changes.

Implementing Ruby features and changes in TruffleRuby is easy thanks to having [73% of all core library methods implemented in Ruby](https://gist.github.com/eregon/912e6359e83781c5fa1c638d3768c526).

## Lazy Method Deserialization

Lazy method deserialization is an optimization that speeds up startup by postponing deserializing, translating, and compiling methods until the first call.

To explain it, let's look at the flow for parsing in TruffleRuby:

1. Parsing from Ruby source code to Prism serialized format, like `Prism.dump`.
2. Deserializing from Prism serialized format to Prism AST, like `Prism.load`.
3. Translating ("Compiling") Prism AST to TruffleRuby AST (corresponds to compilation from AST to bytecode in CRuby).

Once we have a TruffleRuby AST, we can execute it in interpreter, and just-in-time compile it to efficient machine code if called often enough.

TruffleRuby has been using lazy method *translation* for a long time, which makes the 3rd step lazy and means it would lazily translate a method on the first call to that method, from the Prism AST to the TruffleRuby AST.

TruffleRuby 34 goes further and uses lazy method *deserialization*, which also makes the 2nd step lazy.
This optimization reduces parsing time [up to 23%](https://github.com/truffleruby/truffleruby/pull/4182).

In a future release we plan to even make the 1st step lazy and achieve lazy method *parsing*, by caching the Prism serialized format for a given file on disk.
The next time you start TruffleRuby, we can avoid parsing entirely as long as the file was not changed and skip step 1 entirely.

Support for lazy method parsing was envisioned in Prism a long time ago, but only [became possible recently](https://github.com/ruby/prism/pull/3983) by [this change](https://github.com/ruby/prism/pull/3972).

## Ripper is now using Prism::Translation::Ripper

TruffleRuby used to implement `Ripper` by reusing the [`ripper.c` implementation from CRuby](https://github.com/truffleruby/truffleruby/blob/release/33/src/main/c/ripper/ripper.c).
However that was brittle because `ripper.c` relies on lots of CRuby internals and it required a huge amount of work to update to a new Ruby version.

So we decided to switch to the Prism translation layer of Ripper.
We wanted to do this for a while, but had been unable to because `Prism::Translation::Ripper` was not compatible enough.
Thanks to many contributions by `@Earlopain` and `@eregon` in Prism it is now [compatible enough](https://github.com/ruby/prism/issues/3838).

The [PR](https://github.com/truffleruby/truffleruby/pull/4102) switching from `ripper.c` to `Prism::Translation::Ripper` removed 77000 lines 🎉

Ripper is now faster by [20x to 40x on TruffleRuby](https://github.com/truffleruby/truffleruby/pull/4102#issuecomment-3779470664)!
The old implementation had lots of overhead due to very frequent calls between Ruby and C.

We are also seeing more tooling, such as [IRB](https://github.com/ruby/irb/issues/1024) and RDoc, adopt Prism directly, rather than using Ripper. This is great because `Prism` is [about 2.75x faster than Ripper on CRuby](https://eregon.me/blog/2024/10/27/benchmarking-ruby-parsers.html#parsing-and-not-walking) and has a much better API.
We think it is time to [consider deprecating `Ripper`](https://bugs.ruby-lang.org/issues/21827).

## TruffleRuby's StringScanner Implementation in the Gem

The pure-Ruby implementation for `StringScanner` on TruffleRuby [is now in the `strscan` gem](https://github.com/ruby/strscan/blob/master/lib/strscan/truffleruby.rb), instead of being part of the standard library.
This means new methods added in the `strscan` gem will be available on TruffleRuby too when updating the gem.

## Making Hash Parallel, Thread-Safe and Fast at RubyKaigi

If you are attending RubyKaigi 2026 and would like to hear more about TruffleRuby and interesting optimizations,
Benoit Daloze will be giving a talk: [Making Hash Parallel, Thread-Safe and Fast](https://rubykaigi.org/2026/presentations/eregontp.html).

## Give it a Try

Try running your existing application or test suite on TruffleRuby and let us know how it works.

If you find any issue please report it [on GitHub](https://github.com/truffleruby/truffleruby/issues).
You can also reach us [on Slack](https://www.graalvm.org/slack-invitation/) or [on Bluesky](https://bsky.app/profile/truffleruby.dev).
