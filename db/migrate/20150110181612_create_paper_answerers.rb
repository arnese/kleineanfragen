class CreatePaperAnswerers < ActiveRecord::Migration[4.2]
  def change
    create_table :paper_answerers do |t|
      t.references :paper, index: true
      t.references :answerer, polymorphic: true, index: true
    end
    add_foreign_key :paper_answerers, :papers
  end
end
