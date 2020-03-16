# frozen_string_literal: true

class DeleteMuteWorker
  include Sidekiq::Worker

  def perform(account_id, target_account_id)
    account = Account.find(account_id)
    target_account = Account.find(target_account_id)
    if account && target_account
      UnmuteService.new.call(account, target_account)
    end
  end
end
