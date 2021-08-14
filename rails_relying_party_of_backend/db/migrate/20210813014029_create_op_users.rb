class CreateOpUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :op_users do |t|
      t.string :provider
      t.string :uid
      t.string :email

      t.timestamps
    end

    # 追加
    add_index :op_users, %i[provider uid], unique: true
  end
end
