require "spec"
require "../src/slack"
require "webmock"

Spec.before_each &->WebMock.reset
