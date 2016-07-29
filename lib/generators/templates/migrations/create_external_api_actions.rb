class CreateExternalApiActions < ActiveRecord::Migration
  def change
    create_table :external_api_actions do |t|
      t.references :initiator, null: false, polymorphic: true, index: true
      t.string     :type,      null: false

      t.string     :name
      t.string     :method,    null: false
      t.string     :path,      null: false
      t.text       :data
      t.string     :signature
      t.string     :queue, null: false

      t.text       :options

      t.timestamp  :created_at
      t.timestamp  :processed_at
    end
  end
end
