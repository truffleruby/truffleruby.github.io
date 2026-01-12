---
layout: post
title: "TruffleRuby 33 is Released"
authors: ["@eregon", "@nirvdrum", "@andrykonchin"]
---

TruffleRuby 33.0.0 is released and available [on GitHub](https://github.com/truffleruby/truffleruby/releases/tag/graal-33.0.0), in your favorite Ruby installer, and [on Maven Central](https://central.sonatype.com/artifact/dev.truffleruby/truffleruby)!

```bash
$ rbenv install truffleruby-33.0.0
$ ruby-build -d truffleruby-33.0.0 ~/.rubies
$ asdf install ruby truffleruby-33.0.0
$ mise install ruby@truffleruby-33.0.0
$ ruby-install truffleruby
$ rvm install truffleruby
```

There are lots of changes in this release, so let's unpack them one by one.

## New Versioning

TruffleRuby used to follow a year-based versioning scheme, like the Truffle framework.

Starting with TruffleRuby 33, the TruffleRuby major version now represents the first 2 components of `RUBY_VERSION` that TruffleRuby is compatible with.
So TruffleRuby 33 is compatible with Ruby 3.3, TruffleRuby 34 will be compatible with Ruby 3.4, and TruffleRuby 40 with Ruby 4.0.
This way TruffleRuby is able to follow semantic versioning even though CRuby does not.
And of course, it makes it easy to tell which TruffleRuby version is compatible with which Ruby version.

## Thread-Safe Hash

A key feature of this release is that `Hash` is now thread-safe on TruffleRuby.
This fixes an entire class of concurrency bugs where Ruby code accesses a `Hash` from multiple threads without synchronization, which notably happens during `bundle install`.
Previously, we tried to fix the code in these gems but this time we decided to solve this
once and for all in TruffleRuby by making `Hash` fully thread-safe!

For context, `Hash` is thread-safe on CRuby due to the GVL.
TruffleRuby has no GVL and runs threads in parallel, which is great for scalability but presents extra challenges like this one.

Benoit had already implemented a parallel thread-safe `Hash` and wrote [a paper](https://eregon.me/blog/assets/research/thread-safe-collections.pdf) about it as part of his PhD, so we were able to reuse that work.
This implementation of `Hash` is quite sophisticated: it supports parallel reads (`[]`) and parallel writes (`[]=`) while having zero overhead for `Hash` instances reachable by a single `Thread`.
The implementation uses a new kind of lock called a *Lightweight Layout Lock*, described in that paper, as well as non-blocking synchronization techniques.

This new `Hash` implementation is even more thread-safe/reliable than CRuby's `Hash` because it allows mutation during iteration instead of raising transient `RuntimeError`s:

```ruby
h = {}
Thread.new { loop { h.each {} } }
ARGV[0].to_i.times { |i| h[i] = i }
p h.size
```

```
$ ruby -v repro.rb 1_000
ruby 4.0.0 (2025-12-25 revision 553f1675f3) +PRISM [x86_64-linux]
1000

$ ruby -v repro.rb 1_000_000
ruby 4.0.0 (2025-12-25 revision 553f1675f3) +PRISM [x86_64-linux]
...: can't add a new key into hash during iteration (RuntimeError)

$ ruby -v repro.rb 1_000_000
truffleruby 33.0.0 (2026-01-09), like ruby 3.3.7, Oracle GraalVM Native [x86_64-linux]
1000000
```

Note that because `Hash` maintains insertion order, this limits the amount of parallelism on writes due to heavy contention on the last Hash entry.
Therefore a `Concurrent::Map` from [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby) is still recommended when accessing a `Hash` from multiple threads, for better write parallelism and because it provides more concurrency-related methods.

## The Fastest and Easiest Ruby Implementation to Install

With this release, TruffleRuby no longer depends on a system `libssl` and `libyaml`.
That means no more compilation needed when installing TruffleRuby.
As a result, TruffleRuby just became the fastest Ruby to install:

| Command | Time |
| --- | --- |
| $ ruby-build truffleruby-33.0.0 /tmp/truffleruby | 5 seconds |
| $ ruby-build jruby-10.0.2.0 /tmp/jruby | 10 seconds |
| $ ruby-build ruby-4.0.0 /tmp/ruby | 117 seconds |

JRuby is a close second, but CRuby takes about 2 minutes here because it's compiled from source.

TruffleRuby also became the easiest Ruby to install because it only has trivial system dependencies.
Therefore you can simply download and extract it with `curl` and `tar` and run it straight away (pick the right URL for your platform from the [GitHub release](https://github.com/truffleruby/truffleruby/releases/tag/graal-33.0.0)):

```bash
$ time curl -L https://github.com/truffleruby/truffleruby/releases/download/graal-33.0.0/truffleruby-33.0.0-linux-amd64.tar.gz \
  | tar xz && truffleruby-33.0.0-linux-amd64/bin/ruby -v

  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  115M  100  115M    0     0  53.1M      0  0:00:02  0:00:02 --:--:-- 58.1M
truffleruby 33.0.0 (2026-01-09), like ruby 3.3.7, Oracle GraalVM Native [x86_64-linux]
1.92s user 0.95s system 129% cpu 2.211 total
```

<!-- IDEA: asciinema GIF to demo it? -->

That's it. TruffleRuby is installed and ready to use!
You can, for example, run `truffleruby-33.0.0-linux-amd64/bin/ruby` to start IRB.

Note that:
* There is no system dependency: no `libssl`/OpenSSL and no `libyaml` needed!  
  Only `libz` and CA certificates, which `tar` and `curl` already need anyway.
  No need to worry anymore about which OpenSSL version is installed on the system.
* No need to compile anything: it's only download & extract.
* It only takes about 2 seconds!

These released binaries also work as far back as Ubuntu 18.04 and RHEL 8.

## Simpler to Embed in Java

TruffleRuby can be embedded in Java programs, using the [GraalVM Polyglot API](https://www.graalvm.org/sdk/javadoc/org/graalvm/polyglot/Context.html).
This was quite cumbersome in previous TruffleRuby releases because of the need to recompile the `openssl` and `psych` extensions against the system `libssl` and `libyaml`.
Now these system dependencies are gone in TruffleRuby 33 and users who embed TruffleRuby do not have to compile anything: they can simply use the TruffleRuby JARs from Maven Central, and it works without any extra effort or complications.

This feature is particularly useful for Java applications that want to embed Ruby for scripting, configuration, or user-defined extensions.
Now they can also use native extensions.

### New Maven Central Coordinates

TruffleRuby Maven Central coordinates have changed from `org.graalvm.polyglot:ruby` to `dev.truffleruby:truffleruby`.
If you embed TruffleRuby, make sure to update your dependencies accordingly:

To use TruffleRuby from Maven:
```xml
<dependency>
  <groupId>org.graalvm.polyglot</groupId>
  <artifactId>polyglot</artifactId>
  <version>25.0.1</version>
</dependency>
<dependency>
  <groupId>dev.truffleruby</groupId>
  <artifactId>truffleruby</artifactId>
  <version>33.0.0</version>
  <type>pom</type>
</dependency>
```

And from Gradle:
```gradle
implementation("org.graalvm.polyglot:polyglot:25.0.1")
implementation("dev.truffleruby:truffleruby:33.0.0")
```

## Development is Fully in the Open, on GitHub

TruffleRuby is no longer sponsored by Oracle.
Oracle sponsored the development of TruffleRuby for over 10 years and we are grateful for that.
Over the recent years Oracle reduced their investment in Ruby due to shifting focus.

The good news is that the repository moved from `oracle/truffleruby` to `truffleruby/truffleruby`.
This is the best possible outcome as TruffleRuby is now a proper open source project:
* The development happens in the open on GitHub instead of internally inside Oracle, so now anyone can follow the development, participate in discussions, etc.
* PRs are merged faster thanks to a CI running in 20 minutes in GitHub Actions vs hours before.
* There is no need for any Contributor License Agreement anymore to contribute to TruffleRuby; you can simply open a PR and that's it.
* TruffleRuby will be released more frequently, GraalVM was only released every 6 months.
  The release process is now documented and almost fully automated, making it easier and faster to create releases.
* TruffleRuby finally [has its own website](https://truffleruby.dev/) which lists [all blog posts about TruffleRuby](https://truffleruby.dev/) and also [all talks about TruffleRuby](https://truffleruby.dev/talks) since 2014!

This change makes it easier than ever for the community to shape the future of TruffleRuby.

TruffleRuby is also the easiest Ruby implementation to contribute to, thanks to having [73% of all core library methods implemented in Ruby](https://gist.github.com/eregon/912e6359e83781c5fa1c638d3768c526)!

We are currently working on Ruby 3.4 support. If you'd like to contribute, see [this tracking issue](https://github.com/truffleruby/truffleruby/issues/3883).

## Give it a Try

Try running your existing application or test suite on TruffleRuby and let us know how it works.

If you find any issue please report it [on GitHub](https://github.com/truffleruby/truffleruby/issues).
You can also reach us [on Slack](https://www.graalvm.org/slack-invitation/).
