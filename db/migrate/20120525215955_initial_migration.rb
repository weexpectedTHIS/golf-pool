class InitialMigration < ActiveRecord::Migration
  def self.up
    create_table :generic_data do |t|
      t.string :name
      t.text :content
      t.timestamps
    end
    gd = GenericData.find_or_create_by_name('brackets')
    gd.update_attributes!(:content => ([]).to_json)
  end

  def self.down
    drop_table :generic_data
  end
end
