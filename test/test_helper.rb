require 'coveralls'
if Coveralls.will_run?
  Coveralls.wear!
end

require 'simplecov'
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'scorpio'

# NO EXPECTATIONS 
ENV["MT_NO_EXPECTATIONS"] = ''

require 'minitest/autorun'
require 'minitest/around/spec'
require 'minitest/reporters'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

require 'byebug'

class ScorpioSpec < Minitest::Spec
  around do |test|
    test.call
    BlogClean.clean
  end

  def assert_equal exp, act, msg = nil
    msg = message(msg, E) { diff exp, act }
    assert exp == act, msg
  end
end

# register this to be the base class for specs instead of Minitest::Spec
Minitest::Spec.register_spec_type(//, ScorpioSpec)

# boot the blog application in a different process

# find a free port
server = TCPServer.new(0)
$blog_port = server.addr[1]
server.close

$blog_pid = fork do
  require_relative 'blog'

  STDOUT.reopen(Scorpio.root.join('log/blog_webrick_stdout.log').open('a'))
  STDERR.reopen(Scorpio.root.join('log/blog_webrick_stderr.log').open('a'))

  trap('INT') { ::Rack::Handler::WEBrick.shutdown }

  ::Rack::Handler::WEBrick.run(::Blog, Port: $blog_port)
end

# wait for the server to become responsive 
running = false
started = Time.now # TODO should use monotonic
timeout = 30
while !running
  require 'socket'
  begin
    sock=TCPSocket.new('localhost', $blog_port)
    running = true
    sock.close
  rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ECONNABORTED, Errno::EPIPE
    if Time.now > started + timeout
      raise $!.class, "Failed to connect to the server on port #{$blog_port} after #{timeout} seconds.\n\n#{$!.message}", $!.backtrace
    end
    sleep 2**-2
    STDOUT.write('.')
  end
end

Minitest.after_run do
  Process.kill('INT', $blog_pid)
  Process.waitpid
end

require_relative 'blog_scorpio_models'
