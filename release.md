---
runpage:
  required: [version]
  dependencies: [git, gem, docker, curl]
  workdir: self
---

# Madness release checklist

Release verification for Madness. Run this document with
[runpage](https://github.com/DannyBen/runpage):

```console :noop
runpage release.md version:1.3.1
```

## Git is on master and clean

```bash :check
test "$(git branch --show-current)" = master && test -z "$(git status --porcelain)"
```

## Code version

```bash :check
grep -Fq "VERSION = '{{ version }}'" lib/madness/version.rb
```

## Local gem is installed

```bash :check
gem list --local --exact madness --installed --version "{{ version }}" >/dev/null
```

## Published gem version

```bash :check
curl -fsS -o /dev/null "https://rubygems.org/gems/madness/versions/{{ version }}"
```

## Dockerfile version

```bash :check
grep -Fq "gem install madness -v {{ version }}" Dockerfile
```

## Local Docker image version

```bash :check
docker image inspect "dannyben/madness:{{ version }}" >/dev/null
```

## Local Git tag

```bash :check
git rev-parse --quiet --verify "refs/tags/v{{ version }}" >/dev/null
```

## Changelog

```bash :check
grep -Fq "v{{ version }}" CHANGELOG.md
```

## GitHub tag

```bash :check
curl -fsS -o /dev/null "https://github.com/DannyBen/madness/tree/v{{ version }}"
```

## Remote Docker image version

```bash :check
docker pull "dannyben/madness:{{ version }}" >/dev/null
```

## GitHub release

```bash :check
location=$(
  curl -fsSI https://github.com/DannyBen/madness/releases/latest |
    tr -d '\r' |
    awk 'tolower($1) == "location:" { print $2 }' |
    tail -n 1
)
test "$location" = "https://github.com/DannyBen/madness/releases/tag/v{{ version }}"
```
