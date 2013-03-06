module RBase

  class Table
    private_class_method :new

    include Enumerable

    # Create new XBase table file. Table file name will be equal to name with ".dbf" suffix.
    #
    # Allowed options
    #  * :language - language character set used in database. Can be one of LANGUAGE_* constants
    def self.create(name, schema, options = {})
      date = Date.today

      record_size = 1+schema.columns.inject(0) { |size, column| size + column.size }

      data = ''
      data << [0xf5].pack('C') # version
      #data << [0x3].pack('C') # version
      data << [date.year % 100, date.month, date.day].pack('CCC') # last modification date
      data << [0].pack('L') # number of records
      # data << [32+schema.columns.size*32+263+1].pack('v') # data size
      data << [32+schema.columns.size*32+1].pack('v') # data size
      data << [record_size].pack('v') # record size
      data << [].pack('x2') # reserved
      data << [].pack('x') # incomplete transaction
      data << [].pack('x') # encyption flag
      data << [].pack('x4') # reserved
      data << [].pack('x8') # reserved
      data << [0].pack('c') # mdx flag
      data << [options[:language]].pack('C') # language driver
      data << [].pack('x2') # reserved

      offset = 1 # take into account 1 byte for deleted flag
      data << schema.columns.collect do |column|
        s = ''
        s << [column.name.to_s[0..9]].pack('a11') # field name
        s << [column.type].pack('a') # field type
        s << [offset].pack('L') # field data offset
        s << [column.size].pack('C') # field size
        s << [column.decimal || 0].pack('C') # decimal count
        s << [].pack('x2') # reserved
        s << [].pack('x') # work area id
        s << [].pack('x2') # reserved
        s << [].pack('x') # flag for SET FIELDS
        s << [].pack('x7') # reserved
        s << [].pack('x') # index field flag
        offset += column.size
        s
      end.join

      data << [13].pack('C') # terminator

      data << [26].pack('C') # end of file

      File.open("#{name}.dbf", 'wb') do |f|
        f.write data
      end
    end

    # Open table with given name.
    # Table name should be like file name without ".dbf" suffix.
    def self.open(name, options = {})
      table = new
      table.instance_eval { open("#{name}.dbf", options) }
      if block_given?
        result = yield table
        table.close
        result
      else
        table
      end
    end

    # Physically remove records that were marked as deleted from file.
    def pack
      packed_count = 0
      count.times do |i|
        @file.pos = @record_offset + @record_size*i
        data = @file.read(@record_size)
        unless data[0, 1]=='*'
          if i!=packed_count
            @file.pos = @record_offset + @record_size*packed_count
            @file.write data
          end
          packed_count += 1
        end
      end

      file_end = @record_offset + @record_size*packed_count
      @file.pos = file_end
      @file.write "\x1a"
      @file.truncate file_end+1

      self.count = packed_count
      update_header
    end

    def clear
      file_end = @record_offset
      @file.pos = file_end
      @file.write "\x1a"
      @file.truncate file_end+1

      self.count = 0
      update_header
    end

    def close
      @file.close
    end

    attr_reader :name, :count, :columns, :last_modified_on, :language

    # Return instance of RBase::Column for given column name
    def column(name)
      @name_to_columns[name]
    end

    # Returns instance of MemoFile that is associated with table
    def memo
      return @memo_file
    end

    # Create new record, populate it with given attributes
    def build(attributes = {})
      Record.new(self, attributes)
    end

    # Create new record, populate it with given attributes and save it
    def create(attributes = {})
      record = build(attributes)
      record.save
      record
    end

    # Load record stored in position 'index'
    def load(index)
      @file.pos = @record_offset + @record_size*index
      data = @file.read(@record_size)
      record = Record.new(self)
      record.instance_eval { load(index, data) }
      record
    end

    alias_method :[], :load

    def []=(index, record)
      record.instance_eval { @index = index }
      save(record)
    end

    # Iterate through all (even deleted) records
    def each_with_deleted
      return unless block_given?

      count.times do |i|
        yield load(i)
      end
    end

    # Iterate through all non-deleted records
    def each
      return unless block_given?

      self.each_with_deleted do |record|
        yield record unless record.deleted?
      end
    end

    private

    def open(name, options = {})
      @name = File.basename(name, '.dbf')
      @file = File.open(name, "r+b")
      header = @file.read(32)

      year, month, day = *header.unpack('@1ccc')
      year += 2000 if year >= 100

      @last_modified_on = Date.new(year, month, day)
      @count = header.unpack('@4V').first
      @language = header.unpack('@29c').first

      @record_offset = header.unpack('@8v').first
      @record_size = header.unpack('@10v').first

      @file.pos = 32

      @columns = []
      @name_to_columns = {}
      column_options = {}
      column_options[:encoding] = options[:encoding] if options[:encoding]
      while true do
        column_data = @file.read(32)
        break if column_data[0, 1] == "\x0d"
        name, type, offset, size, decimal = *column_data.unpack('@0a11aLCC')
        name = name.strip
        @columns << Columns::Column.column_for(type).new(name, options.merge(:offset => offset, :size => size, :decimal => decimal))
        @name_to_columns[name.upcase.to_sym] = @columns.last
      end

      @columns.each { |column| column.attach_to(self) }

      @memo_file = MemoFile::DummyMemoFile.new
    end

    def save(record)
      if !record.index
        @file.pos = @record_offset + @record_size*count
        @file.write record.serialize
        @file.write [26].pack('c')
        record.instance_variable_set(:@index, count)
        self.count = count + 1
      else
        throw "Index out of bound" if record.index>=count
        @file.pos = @record_offset + @record_size*record.index
        @file.write record.serialize
      end
      update_header
    end

    def count=(value)
      @count = value
    end

    def last_modified_on=(value)
      @last_modified_on = value
    end

    def update_header
      @last_modified_on = Date.today
      @file.pos = 1
      @file.write([last_modified_on.year % 100, last_modified_on.month, last_modified_on.day].pack('ccc'))
      @file.write([count].pack('V'))
    end
  end

end
