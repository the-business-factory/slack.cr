require "./spec_helper"
require "./support/compile_contracts"

describe CompileContracts do
  it "does not confuse dependency failures or compiler crashes with intended diagnostics" do
    failed = Process::Status[1]
    {
      "can't find file 'missing'; expected diagnostic" => "dependency failure",
      "Please report a bug: expected diagnostic"       => "compiler crashed",
      "Invalid memory access: expected diagnostic"     => "compiler crashed",
    }.each do |output, reason|
      result = CompileContracts::Result.new("synthetic.cr", failed, output, Time::Span.zero)
      expect_raises(Exception, reason) { CompileContracts.assert_fail(result, ["expected diagnostic"]) }
    end
  end

  it "rejects successful compilation and unrelated errors" do
    successful = CompileContracts::Result.new("synthetic.cr", Process::Status[0], "expected diagnostic", Time::Span.zero)
    expect_raises(Exception, "to fail compilation") { CompileContracts.assert_fail(successful, ["expected diagnostic"]) }
    unrelated = CompileContracts::Result.new("synthetic.cr", Process::Status[1], "different error", Time::Span.zero)
    expect_raises(Exception, "expected diagnostic") { CompileContracts.assert_fail(unrelated, ["expected diagnostic"]) }
  end
end
