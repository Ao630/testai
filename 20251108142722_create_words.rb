class CreateWords < ActiveRecord::Migration[6.1]
  def change
    create_table :words do |t|
      t.integer :file, default: 0
      t.string :word, default: "用語"
      t.string :mean, default: "定義"
      t.string :longjapan
      t.string :longenglish
      t.string :status
      t.integer :user_id
      t.timestamps
    end
  end
end
