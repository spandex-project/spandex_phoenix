# Changelog

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v1.0.6](https://github.com/spandex-project/spandex_phoenix/compare/1.0.5...v1.0.6) (2021-10-23)

* fix: function :function_clause.__struct__/0 is undefined by @fuelen in https://github.com/spandex-project/spandex_phoenix/pull/43
* Tweak router exception handling and CI clean-up by @GregMefford in https://github.com/spandex-project/spandex_phoenix/pull/45
* Update maintainers and sponsor link by @GregMefford in https://github.com/spandex-project/spandex_phoenix/pull/50

## [v1.0.5](https://github.com/spandex-project/spandex_phoenix/compare/1.0.4...v1.0.5) (2020-11-25)

### Bug Fixes:

* System.stacktrace() -> __STACKTRACE__

* UnsupportedMediaTypeError not an error span

## [v1.0.4](https://github.com/spandex-project/spandex_phoenix/compare/1.0.3...v1.0.4) (2020-09-11)

### Bug Fixes:

- Close span instead of trace on router exception

## [v1.0.3](https://github.com/spandex-project/spandex_phoenix/compare/1.0.2...v1.0.3) (2020-07-15)

### Bug Fixes:

- filter traces

## [v1.0.2](https://github.com/spandex-project/spandex_phoenix/compare/1.0.1...v1.0.2) (2020-07-13)

### Bug Fixes:

- Allow traces to be filtered in telemetry (#33)

## [v1.0.1](https://github.com/spandex-project/spandex_phoenix/compare/1.0.0...v1.0.1) (2020-07-12)

### Bug Fixes:

- support phx 1.5 properly

## [v1.0.0](https://github.com/spandex-project/spandex_phoenix/compare/0.4.2...v1.0.0) (2020-07-01)

### Breaking Changes:

- Add Phx 1.5 Telemetry Handlers (#26)

## [v0.4.2](https://github.com/spandex-project/spandex_phoenix/compare/0.4.1...v0.4.2) (2020-5-26)

### Bug Fixes:

- update spandex version dependency

## [v0.4.1](https://github.com/spandex-project/spandex_phoenix/compare/0.4.0...v0.4.1) (2019-5-14)

### Bug Fixes:

- Fix compilation errors when instrumenting a `Plug` without `Phoenix`.

## [v0.4.0](https://github.com/spandex-project/spandex_phoenix/compare/0.3.2...v0.4.0) (2019-4-2)

### Features:

- Normalize Phoenix.NoRouteErrors into a single resource name, "Not Found"

## [v0.3.2](https://github.com/spandex-project/spandex_phoenix/compare/0.3.1...v0.3.2) (2019-2-4)

### Bug Fixes:

- decode URI's properly

## [v0.3.1](https://github.com/spandex-project/spandex_phoenix/compare/0.3.0...v0.3.1) (2018-12-20)

### Bug Fixes:

- Configure tracer runtime instead of compile time

## [v0.3.0](https://github.com/spandex-project/spandex_phoenix/compare/0.2.1...v0.2.1) (2018-11-19)

### Bug Fixes:

- Return a conn when the request is filtered

### Features:

- Add a Plug wrapper to trace requests

### Bug Fixes:

- Require at least Plug 1.3

## [0.2.1](https://github.com/spandex-project/spandex_phoenix/compare/v0.2.0...v0.2.1) (2018-11-10)

### Bug Fixes:

- Require at least Plug 1.3

  We depend on `Plug.Conn.path_params`, which was added in Plug 1.3.0.

## [0.2.0](https://github.com/spandex-project/spandex_phoenix/compare/v0.1.1...v0.2.0) (2018-11-8)

### Features:

- Add a Plug wrapper to trace requests

## [0.1.1](https://github.com/spandex-project/spandex_phoenix/compare/v0.1.0...v0.1.1) (2018-10-15)

### Bug Fixes:

- Indirectly call Tracer to remove compiler warnings ([#1](https://github.com/spandex-project/spandex_phoenix/pull/1))

## [0.1.0](https://github.com/spandex-project/spandex_phoenix/tree/v0.1.0) (2018-09-15)

### Features:

- Initial release! 🚀 🎉
