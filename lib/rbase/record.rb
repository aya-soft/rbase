module RBase

  class StandardError < Exception; end

  class UnknownColumnError < StandardError
    attr_reader :name

    def initialize(name)
      super("Unknown column '#{name}'")
      @name = name
    end
  end

  class InvalidValueError < StandardError
    attr_reader :column, :value

    def initialize(column, value)
      super("Invalid value #{value.inspect} for column #{column.inspect}")
      @column, @value = column, value
    end
  end

  # Class that contains data for particular table row.
  # Should not be created explicitly (use Table#create to create records)
  #
  # == Accessing attributes
  #
  # You can read and assign values to row's columns using simple property syntax:
  #
  #   user = users_table[0]
  #   user.name = 'Bob'
  #   user.birth_date = Date.new(1980, 2, 29)
  #   user.save
  #
  #   puts user.name
  #   puts user.birth_date
  #
  class Record
    attr_reader :table, :index

    def initialize(table, attributes = {})
      @table = table
      @values_cached = {}
      @values_changed = {}

      attributes.each { |k, v| @values_changed[k.to_s.upcase] = v }
    end

    private

    def load(index, data)
      @table = table
      @index = index
      @data = data.dup
    end

    public

    # Returns true if record was never saved to database; otherwise return false.
    def new_record?
      @data.nil?
    end

    # Save record to database.
    def save
      record = self
      @table.instance_eval { save(record) }
    end

    # Delete record from database.
    def delete
      @deleted = true
      save
    end

    # Returns true if record was marked as deleted; otherwise return false.
    def deleted?
      @deleted ||= new_record? ? false : @data[0, 1] == '*'
    end

    # Clone record.
    def clone
      c = self.class.new(@table, @values_changed)
      c.instance_variable_set("@values_cached", @values_cached)
      c.instance_variable_set("@data", @data)
      c
    end

    def method_missing(sym, *args)
      name = sym.to_s
      if /=$/ =~ name && args.size == 1
        set_value(name[0..-2], args.first)
      else
        get_value(name)
      end
    end

    def serialize
      if new_record?
        @data = deleted? ? '*' : ' '
        @data << @table.columns.collect do |column|
          column.pack(@values_changed[column.name])
        end.join
      else
        @data[0, 1] = deleted? ? '*' : ' '
        @values_changed.each do |k, v|
          column = @table.column(k)
          raise UnknownColumnError.new(k) unless column
          begin
            @data[column.offset, column.size] = column.pack(v)
          rescue Object => e
            raise InvalidValueError.new(column, v)
          end
          @values_cached[k] = v
        end
      end
      @data
    end

    protected

    # Returns value of specified column
    def get_value(name)
      name = name.to_s.upcase.to_sym
      return @values_changed[name] if @values_changed.has_key?(name)
      return nil if new_record?
      column = @table.column(name)
      raise UnknownColumnError.new(name) unless column
      @values_cached[name] ||= column.unpack(@data[column.offset, column.size])
    end

    # Sets value of specified column.
    def set_value(name, value)
      name = name.to_s.upcase.to_sym
      raise UnknownColumnError.new(name) unless @table.column(name)
      @values_changed[name] = value
    end
  end

end

