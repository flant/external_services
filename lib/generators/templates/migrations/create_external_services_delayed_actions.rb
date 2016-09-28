class CreateExternalServicesDelayedActions < ActiveRecord::Migration
  def change
    create_table :external_services_delayed_actions do |t|
      t.string :type
      t.text :arguments
      t.integer :last_processed_step
      t.string :sync_key

      t.timestamps

      t.timestamp :processed_at
    end
  end
end
