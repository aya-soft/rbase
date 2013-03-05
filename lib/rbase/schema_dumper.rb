module RBase

  class SchemaDumper
    # Produce ruby schema for a given table.
    #
    # Parameters
    #   table - instance of RBase::Table opened
    #
    # == Example
    #
    #   users = RBase::Table.open('users')
    #   File.open('users.dump.rb', 'w') do |f|
    #     f.write RBase::SchemaDumper.dump(users)
    #   end
    #   users.close
    #
    def self.dump(table)
      output = ''
      output << "RBase.create_table :#{table.name} do |t|\n"
      
      table.columns.each do |column|
        output << "  t.column '#{column.name}', '#{column.type}', :size => #{column.size}#{ (column.decimal && column.decimal > 0) ? ", :decimal => #{column.decimal}" : ''}\n"
      end
      
      output << "end\n"
    end
  end
  
end
