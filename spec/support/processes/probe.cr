require "./rotation_probe"
require "./storage_probe"

# Subprocess fixture for the cross-process rotation and durable-storage specs.
# Arguments: working directory, suite (`rotation` or `storage`), action, identity.
# The parent and the probes synchronize through files in the working directory.
directory, suite, action, identity = ARGV
case suite
when "rotation" then SpecSupport::RotationProbe.run(directory, action, identity)
when "storage"  then SpecSupport::StorageProbe.run(directory, action, identity)
else
  abort "unknown probe suite: #{suite}"
end
