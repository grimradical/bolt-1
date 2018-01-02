require 'spec_helper'
require 'bolt/outputter'
require 'bolt/cli'

describe "Bolt::Outputter::Human" do
  let(:output) { StringIO.new }
  let(:outputter) { Bolt::Outputter::Human.new(output) }
  let(:results) { { node1: Bolt::Result.new("ok") } }
  let(:config)  { Bolt::Config.new }

  it "starts items in head" do
    outputter.print_head
    expect(output.string).to eq('')
  end

  it "allows empty items" do
    outputter.print_head
    outputter.print_summary({}, 2.0)
    expect(output.string).to eq("Ran on 0 nodes in 2.00 seconds\n")
  end

  it "prints status" do
    outputter.print_head
    outputter.print_result(Bolt::Node.from_uri('node1', config: config),
                           Bolt::Result.new)
    outputter.print_result(Bolt::Node.from_uri('node2', config: config),
                           Bolt::Result.new('msg' => 'oops'))
    outputter.print_summary(results, 10.0)
    lines = output.string
    expect(lines).to match(/Finished on node1/)
    expect(lines).to match(/Failed on node2/)
    expect(lines).to match(/oops/)
  end

  it "prints CommandResults" do
    outputter.print_result(Bolt::Node.from_uri('node1', config: config),
                           Bolt::CommandResult.new("stout", "sterr", 2))
    lines = output.string
    expect(lines).to match(/STDOUT:\n    stout/)
    expect(lines).to match(/STDERR:\n    sterr/)
  end

  it "prints TaskResults" do
    result = { 'key' => 'val',
               '_error' => { 'msg' => 'oops' },
               '_output' => 'hello' }
    outputter.print_result(Bolt::Node.from_uri('node1', config: config),
                           Bolt::TaskResult.new(result.to_json, "", 2))
    lines = output.string
    expect(lines).to match(/^  oops\n  hello$/)
    expect(lines).to match(/^    "key": "val"$/)
  end

  it "handles fatal errors" do
    outputter.fatal_error(Bolt::CLIError.new("oops"))
    expect(output.string).to eq('')
  end
end
