# frozen_string_literal: true

class HomeMediaFeed < HomeFeed
  def initialize(account)
    @subtype = 'media'
    super account
  end

  def key
    FeedManager.instance.key(@type, @id, @subtype)
  end

  def regenerating?
    redis.exists?("account:#{@account.id}:media:regeneration")
  end
end
