module RBase
  module MemoFile
  
    class DummyMemoFile
      def read(index)
        ''
      end
      
      def write(value)
        nil
      end
    end

    class DBase3MemoFile
      HEADER_SIZE = 512
      BLOCK_SIZE = 512
      BLOCK_TERMINATOR = "\x1a\x1a"
      
      def initialize(name)
        @file = File.open(name)
        
        @header = @file.read(HEADER_SIZE)
        @next_block = header.unpack('@0L')
        @version = header.unpack('@16c')
      end
      
      def read(index)
        @file.pos = index*BLOCK_SIZE + HEADER_SIZE

        result = ''
        loop do
          data = @file.read(BLOCK_SIZE)
          terminator_pos = data.index(BLOCK_TERMINATOR)
          if terminator_pos
            break result + data[0, terminator_pos]
          end
          result += data
        end
      end
      
      def write(value)
        @file.pos = @next_block*BLOCK_SIZE + HEADER_SIZE
        value += BLOCK_TERMINATOR
        blocks_num = (value.length+511)/512
        @file.write [value].pack("a#{512*blocks_num}")
        
        position = @next_block
        @next_block += blocks_num
        update_header
        
        position
      end
      
      protected
      
      def update_header
        @file.pos = 0
        @file.write [@next_block].pack("L")
      end
    end

  end
end
