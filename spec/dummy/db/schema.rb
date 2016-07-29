# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20_160_729_101_755) do
  create_table 'external_api_actions', force: :cascade do |t|
    t.string   'initiator_type', null: false
    t.integer  'initiator_id',   null: false
    t.string   'type',           null: false
    t.string   'name'
    t.string   'method',         null: false
    t.string   'path',           null: false
    t.text     'data'
    t.string   'signature'
    t.string   'queue', null: false
    t.text     'options'
    t.datetime 'created_at'
    t.datetime 'processed_at'
    t.index %w(initiator_type initiator_id), name: 'index_external_api_actions_on_initiator_type_and_initiator_id'
  end

  create_table 'external_services', force: :cascade do |t|
    t.string  'subject_type', null: false
    t.integer 'subject_id',   null: false
    t.string  'type',         null: false
    t.string  'external_id'
    t.text    'extra_data'
    t.index ['external_id'], name: 'index_external_services_on_external_id'
    t.index %w(subject_type subject_id), name: 'index_external_services_on_subject_type_and_subject_id'
  end

  create_table 'posts', force: :cascade do |t|
    t.string   'name'
    t.string   'value'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
  end
end
