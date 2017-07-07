#!/usr/bin/env ruby
# encoding:utf-8

class Lock
  def initialize(rsc, mode="w")
    @lockfile = "/tmp/#{rsc}.lock"
	@fp = open(@lockfile, mode)
  end
  
  def lock
    return @fp.flock(File::LOCK_EX)
  end
  
  def unlock
    return @fp.flock(File::LOCK_UN)
  end
  
  def close
    @fp.flock(File::LOCK_UN)
    @fp.close()
  end
  
  def remove
    `rm #{@lockfile}`
  end
end

### test driver
=begin
puts "blocking.."
lock = Lock.new("port10000")
puts lock.lock()
puts "sleep"
sleep 5 if ARGV[0] == "w"
puts lock.unlock()
puts "unlock"
lock.close()
=end
