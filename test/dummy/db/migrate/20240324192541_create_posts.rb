class CreatePosts < ActiveRecord::Migration["#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}"]
  def change
    create_table :posts do |t|
      t.string :title
      t.string :content, null: false

      t.references :user, null: false

      t.timestamps
    end
  end
end
