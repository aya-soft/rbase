require 'rbase/columns'

module RBase

  class Schema
    # Returns list of all columns defined.
    attr_reader :columns

    def initialize
      @columns = []
    end

    # Declares new column.
    #
    # Options:
    #
    # * :size - size of the column in characters
    # * :decimal - number of decimal positions
    #
    # There are column types that require it's size to be specified (but they still have reasonable defaults).
    # But some column types (e.g. :date type) have fixes size that cannot be overriden.
    #
    # There are several column types available:
    #
    # * :string - corresponds to fixed length character column. Column size is limited to 254 (default).
    # * :date - date column type
    # * :boolean - logical column type
    # * :integer - number column type. Number is stored in human readable form
    #   (text representation), so you should specify it's size in characters. Maximum column size is 18 (default).
    #   If :decimal option not equal to 0, number contains <:decimal> fraction positions.
    #   You should adjust :size keeping :decimal positions + 1 (for decimal point) in mind.
    # * :memo - memo column. Memo is a text field that can be more than 254 chars long. Memo data is stored in separate file.
    #   This column type is not yet supported.
    #
    #
    def column(name, type, options = {})
      name = name.to_s.upcase
      case type
      when :string then type = 'C'
      when :integer then type = 'N'
      when :float then
        type = 'N'
        options[:decimal] ||= 6
      when :boolean then type = 'L'
      when :date then type = 'D'
      end
      
      @columns << Columns::Column.column_for(type).new(name, options)
    end
  end

end
