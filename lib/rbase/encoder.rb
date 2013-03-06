class Encoder

  def initialize(from, to)
    @from, @to = from, to
  end

  def en(str)
    str.force_encoding(@from).encode(@to)
  end

end