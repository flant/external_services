class CreateExternalServices < ActiveRecord::Migration[5.0]
  def change
    create_table :external_services do |t|
      t.references :subject, null: false, polymorphic: true, index: true

      t.string     :type,    null: false
      t.string     :external_id
      t.text       :extra_data
    end
    add_index :external_services, :external_id
  end
end
