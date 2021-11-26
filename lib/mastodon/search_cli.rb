# frozen_string_literal: true

require_relative '../../config/boot'
require_relative '../../config/environment'
require_relative 'cli_helper'

module Mastodon
  class SearchCLI < Thor
    include CLIHelper

    # Indices are sorted by amount of data to be expected in each, so that
    # smaller indices can go online sooner
    INDICES = [
      AccountsIndex,
      TagsIndex,
      StatusesIndex,
    ].freeze

    option :concurrency, type: :numeric, default: 2, aliases: [:c], desc: 'Workload will be split between this number of threads'
    option :batch_size, type: :numeric, default: 1_000, aliases: [:b], desc: 'Number of records in each batch'
    option :only, type: :array, enum: %w(accounts tags statuses), desc: 'Only process these indices'
    desc 'deploy', 'Create or upgrade ElasticSearch indices and populate them'
    long_desc <<~LONG_DESC
      If ElasticSearch is empty, this command will create the necessary indices
      and then import data from the database into those indices.

      This command will also upgrade indices if the underlying schema has been
      changed since the last run.

      Even if creating or upgrading indices is not necessary, data from the
      database will be imported into the indices.
    LONG_DESC
    def deploy
      if options[:concurrency] < 1
        say('Cannot run with this concurrency setting, must be at least 1', :red)
        exit(1)
      end

      if options[:batch_size] < 1
        say('Cannot run with this batch_size setting, must be at least 1', :red)
        exit(1)
      end

      indices = begin
        if options[:only]
          options[:only].map { |str| "#{str.camelize}Index".constantize }
        else
          INDICES
        end
      end

      progress = ProgressBar.create(total: nil, format: '%t%c/%u |%b%i| %e (%r docs/s)', autofinish: false)

      # Create indices with new suffixes if specification is changed.
      suffix = (Time.now.to_f * 1000).round
      indices.select { |index| index.specification.changed? }.each do |index|
        index.create! suffix, alias: false
      end

      db_config = ActiveRecord::Base.configurations[Rails.env].dup
      db_config['pool'] = options[:concurrency] + 1
      ActiveRecord::Base.establish_connection(db_config)

      pool    = Concurrent::FixedThreadPool.new(options[:concurrency])
      added   = Concurrent::AtomicFixnum.new(0)
      removed = Concurrent::AtomicFixnum.new(0)

      progress.title = 'Estimating workload '

      # Estimate the amount of data that has to be imported first
      indices.each do |index|
        index.types.each do |type|
          progress.total = (progress.total || 0) + type.adapter.default_scope.count
        end
      end

      # Now import all the actual data. Mind that unlike chewy:sync, we don't
      # fetch and compare all record IDs from the database and the index to
      # find out which to add and which to remove from the index. Because with
      # potentially millions of rows, the memory footprint of such a calculation
      # is uneconomical. So we only ever add.
      indices.each do |index|
        progress.title = "Importing #{index} "
        batch_size     = options[:batch_size]
        slice_size     = (batch_size / options[:concurrency]).ceil

        index.types.each do |type|
          type.adapter.default_scope.reorder(nil).find_in_batches(batch_size: batch_size) do |batch|
            futures = []

            batch.each_slice(slice_size) do |records|
              futures << Concurrent::Future.execute(executor: pool) do
                begin
                  if !progress.total.nil? && progress.progress + records.size > progress.total
                    # The number of items has changed between start and now,
                    # since there is no good way to predict the final count from
                    # here, just change the progress bar to an indeterminate one

                    progress.total = nil
                  end

                  grouped_records = nil
                  bulk_body       = nil
                  index_count     = 0
                  delete_count    = 0

                  ActiveRecord::Base.connection_pool.with_connection do
                    grouped_records = type.adapter.send(:grouped_objects, records)
                    bulk_body       = Chewy::Type::Import::BulkBuilder.new(type, **grouped_records).bulk_body
                  end

                  index_count  = grouped_records[:index].size  if grouped_records.key?(:index)
                  delete_count = grouped_records[:delete].size if grouped_records.key?(:delete)

                  # The following is an optimization for statuses specifically, since
                  # we want to de-index statuses that cannot be searched by anybody,
                  # but can't use Chewy's delete_if logic because it doesn't use
                  # crutches and our searchable_by logic depends on them
                  if type == StatusesIndex::Status
                    bulk_body.map! do |entry|
                      if entry[:index] && entry.dig(:index, :data, 'searchable_by').blank?
                        index_count  -= 1
                        delete_count += 1

                        { delete: entry[:index].except(:data) }
                      else
                        entry
                      end
                    end
                  end

                  if index.specification.changed?
                    Chewy::Type::Import::BulkRequest.new(type, suffix: suffix).perform(bulk_body)
                  else
                    Chewy::Type::Import::BulkRequest.new(type).perform(bulk_body)
                  end

                  progress.progress += records.size

                  added.increment(index_count)
                  removed.increment(delete_count)

                  sleep 1
                rescue => e
                  progress.log pastel.red("Error importing #{index}: #{e}")
                end
              end
            end

            futures.map(&:value)
          end
        end
      end

      progress.title = ''
      progress.stop

      say("Indexed #{added.value} records, de-indexed #{removed.value}", :green, true)

      # Switch aliases, like chewy:reset.
      indices.select { |index| index.specification.changed? }.each do |index|
        old_indices = index.indexes - [index.index_name]
        general_name = index.index_name

        index.delete if old_indices.blank?
        actions = [
          *old_indices.map do |old_index|
            { remove: { index: old_index, alias: general_name } }
          end,
          { add: { index: index.index_name(suffix: suffix), alias: general_name } }
        ]
        Chewy.client.indices.update_aliases body: { actions: actions }

        Chewy.client.indices.delete index: old_indices if old_indices.present?

        index.specification.lock!
      end
    end
  end
end
