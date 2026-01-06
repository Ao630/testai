class CreateFolders < ActiveRecord::Migration[6.1]
  def change
    create_table :folders do |t|
      t.integer :file, default: 0
      t.string :filename, default: "ファイル名"
      t.string :status
      t.integer :user_id
      t.timestamps
    end
  end
end
