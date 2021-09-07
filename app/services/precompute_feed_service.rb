# frozen_string_literal: true

class PrecomputeFeedService < BaseService
  def call(account)
    FeedManager.instance.populate_home(account)
  ensure
    Redis.current.del("account:#{account.id}:regeneration")
    Redis.current.del("account:#{account.id}:media:regeneration")
  end
end
