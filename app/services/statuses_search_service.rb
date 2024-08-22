# frozen_string_literal: true

class StatusesSearchService < BaseService
  def call(query, account = nil, options = {})
    @query   = query&.strip
    @account = account
    @options = options
    @limit   = options[:limit].to_i
    @offset  = options[:offset].to_i

    convert_deprecated_options!
    status_search_results
  end

  private

  def status_search_results
    results = Status.where(visibility: :public)
                    .where('statuses.text &@~ ?', @query)
                    .searchable_by_account(@account)
                    .offset(@offset)
                    .limit(@limit)
                    .order('statuses.id DESC')

    results = results.where(account_id: @options[:account_id]) if @options[:account_id].present?

    if @options[:min_id].present? || @options[:max_id].present?
      results = results.where('statuses.id > ?', @options[:min_id]) if @options[:min_id].present?
      results = results.where('statuses.id < ?', @options[:max_id]) if @options[:max_id].present?
    end

    account_ids         = results.map(&:account_id)
    account_domains     = results.map(&:account_domain)
    preloaded_relations = @account.relations_map(account_ids, account_domains)

    results.reject { |status| StatusFilter.new(status, @account, preloaded_relations).filtered? }
  end

  def convert_deprecated_options!
    syntax_options = []

    if @options[:account_id]
      username = Account.select(:username, :domain).find(@options[:account_id]).acct
      syntax_options << "from:@#{username}"
    end

    if @options[:min_id]
      timestamp = Mastodon::Snowflake.to_time(@options[:min_id].to_i)
      syntax_options << "after:\"#{timestamp.iso8601}\""
    end

    if @options[:max_id]
      timestamp = Mastodon::Snowflake.to_time(@options[:max_id].to_i)
      syntax_options << "before:\"#{timestamp.iso8601}\""
    end

    @query = "#{@query} #{syntax_options.join(' ')}".strip if syntax_options.any?
  end
end
