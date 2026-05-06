class CreateDiscoverySteps < ActiveRecord::Migration[8.1]
  def change
    create_table :discovery_steps, id: :uuid do |t|
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.integer :step_number, null: false
      t.string  :step_name,   null: false
      t.text    :user_input
      t.text    :gemini_output
      t.text    :gemini_raw
      t.boolean :completed,   null: false, default: false

      t.timestamps null: false
    end

    add_index :discovery_steps, [:product_id, :step_number], unique: true
  end
end
