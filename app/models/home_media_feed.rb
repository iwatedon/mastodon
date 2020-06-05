# frozen_string_literal: true

class HomeMediaFeed < HomeFeed
  def initialize(account)
    @subtype = 'media'
    super account
  end

  def key
    FeedManager.instance.key(@type, @id, @subtype)
  end
end
