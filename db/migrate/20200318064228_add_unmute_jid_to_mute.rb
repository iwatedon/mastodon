class AddUnmuteJidToMute < ActiveRecord::Migration[5.2]
  def change
    add_column :mutes, :unmute_jid, :string
  end
end
