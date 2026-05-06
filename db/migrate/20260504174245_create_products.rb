class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string  :name,            null: false, limit: 120
      t.string  :target_customer, null: false, limit: 200
      t.string  :strategic_goal,  null: false, limit: 300

      t.timestamps null: false
    end

    add_index :products, :created_at
  end
end
