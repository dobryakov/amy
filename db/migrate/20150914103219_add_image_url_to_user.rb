class AddImageUrlToUser < ActiveRecord::Migration
  def change
    add_column :users, :image_url, :text
  end
end
