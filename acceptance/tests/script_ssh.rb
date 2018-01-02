require 'bolt_command_helper'
extend Acceptance::BoltCommandHelper

test_name "C100548: \
           bolt script run should execute script on remote hosts via ssh" do

  ssh_nodes = select_hosts(roles: ['ssh'])
  skip_test('no applicable nodes to test on') if ssh_nodes.empty?

  script = "C100548.sh"

  step "create script on bolt controller" do
    create_remote_file(bolt, script, <<-FILE)
    #!/bin/sh
    echo "hello from $(hostname)"
    FILE
  end

  step "execute `bolt script run` via SSH" do
    user = ENV['SSH_USER']
    password = ENV['SSH_PASSWORD']
    nodes_csv = ssh_nodes.map(&:hostname).join(',')
    bolt_command = "bolt script run #{script}"

    flags = {
      '--nodes'     => nodes_csv,
      '-u'          => user,
      '-p'          => password,
      '--insecure'  => nil
    }

    result = bolt_command_on(bolt, bolt_command, flags)
    ssh_nodes.each do |node|
      message = "Unexpected output from the command:\n#{result.cmd}"
      regex = /hello from #{node.hostname.split('.')[0]}/
      assert_match(regex, result.stdout, message)
    end
  end
end
