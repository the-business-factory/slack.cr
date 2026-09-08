require "spec"
require "lucky_env"
require "../src/slack"
require "webmock"

LuckyEnv.load(".env.test")

Spec.before_each &->WebMock.reset
