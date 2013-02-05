require 'spec_helper'

describe Warden::GitHub::User do
  let(:default_attrs) do
    { 'login' => 'john',
      'name' => 'John Doe',
      'gravatar_id' => '38581cb351a52002548f40f8066cfecg',
      'email' => 'john@doe.com',
      'company' => 'Doe, Inc.' }
  end
  let(:token) { 'the_token' }

  let(:user) do
    described_class.new(default_attrs, token)
  end

  describe '#token' do
    it 'returns the token' do
      user.token.should eq token
    end
  end

  %w[login name gravatar_id email company].each do |name|
    describe "##{name}" do
      it "returns the #{name}" do
        user.send(name).should eq default_attrs[name]
      end
    end
  end

  describe '#api' do
    it 'returns a preconfigured Octokit client for the user' do
      api = user.api

      api.should be_an Octokit::Client
      api.login.should eq user.login
      api.oauth_token.should eq user.token
    end
  end

  def stub_api(user, method, args, ret)
    api = double
    user.stub(:api => api)
    api.should_receive(method).with(*args).and_return(ret)
  end

  [:organization_public_member?, :organization_member?].each do |method|
    describe "##{method}" do
      it 'asks the api for the member status' do
        status = double
        stub_api(user, method, ['rails', user.login], status)

        user.send(method, 'rails').should be status
      end
    end
  end

  describe '#team_member?' do
    it 'asks the api for team members' do
      status = double
      stub_api(user, :team_members, [123], false)

      user.team_member?(123)
    end

    context 'when user is not member' do
      it 'returns false' do
        api = double
        user.stub(:api => api)

        # api.stub(:team_member?, [123, user.login]).and_raise(Octokit::NotFound.new({}))
        api.stub(:team_members, [123]).and_raise(Octokit::NotFound.new({}))

        user.should_not be_team_member(123)
      end
    end

    context 'when user is member' do
      it 'returns true' do
        api = double
        user.stub(:api => api)
        # api.stub(:team_member?, [123, user.login])
        api.stub(:team_members, [123])

        user.should be_team_member(123)
      end
    end
  end

  describe '.load' do
    it 'loads the user data from GitHub and creates an instance' do
      client = double
      attrs = {}

      Octokit::Client.
        should_receive(:new).
        with(:oauth_token => token).
        and_return(client)
      client.should_receive(:user).and_return(attrs)

      user = described_class.load(token)

      user.attribs.should eq attrs
      user.token.should eq token
    end
  end

  # NOTE: This always passes on MRI 1.9.3 because of ruby bug #7627.
  it 'marshals correctly' do
    Marshal.load(Marshal.dump(user)).should eq user
  end
end
