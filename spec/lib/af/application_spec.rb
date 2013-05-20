require 'spec_helper'

class MyScript < Af::Application
  opt :bar

  def work
    puts "baz"
  end
end

describe Af::Application do
  include ScriptSpecHelper

  subject { MyScript.new }

  it "returns class name when #af_name is called" do
    subject.af_name.should == "MyScript"
  end

  it "sets connections name when #set_connection_application_name is called" do
    subject.send(:set_connection_application_name, "Application name")
    ActiveRecord::ConnectionAdapters::ConnectionPool.connection_application_name.should == "Application name"
  end

  it "returns process PID and af name when #startup_database_application_name is called" do
    subject.send(:startup_database_application_name).should =~ /MyScript$/
  end

  it "returns Log4r::Logger instance" do
    subject.logger.should be_kind_of(Log4r::Logger)
  end

  it "performs code from work method" do
    subject.should_receive(:puts).with("baz")
    subject.work
  end

end # Af::Application
