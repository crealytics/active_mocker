require 'spec_helper'
require 'lib/post_methods'
require_relative 'mocks/micropost_mock.rb'
require_relative 'mocks/user_mock.rb'
require_relative 'mocks/relationship_mock'
require_relative 'mocks/account_mock'

describe ActiveMocker::Feature do

  describe 'turn of auto record associations' do

    before do
      ActiveMocker::Feature.auto_association = false
    end

    after do
      ActiveMocker::Feature.auto_association = true
    end

    it 'will not set the foreign_key from the objects id' do
      user = UserMock.create(account: AccountMock.create)
      expect(user.account).to eq AccountMock.first
      expect(user.account.user_id).to eq nil
    end

    it 'setting user will not assign its foreign key' do
      user = UserMock.create!
      post = MicropostMock.create(user: user)
      expect(post.user).to eq user
      expect(post.user_id).to eq nil
    end

    it 'when passing in collection all item in collection will not set its foreign key to the parent' do
      posts = [MicropostMock.create, MicropostMock.create, MicropostMock.create]
      user = UserMock.create(microposts: posts)
      expect(user.microposts).to eq posts
      expect(posts.map(&:user_id).all?(&:nil?)).to eq true
    end

  end

end
