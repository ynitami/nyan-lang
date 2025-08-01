class NyanError < StandardError
  attr_reader :error_type, :line, :column

  def initialize(error_type, message, line = nil, column = nil)
    @error_type = error_type
    @line = line
    @column = column
    super(format_message(message))
  end

  private

  def format_message(message)
    location = @line ? "#{@line}:#{@column} - " : ""
    "#{location}#{get_cat_prefix}#{message}"
  end

  def get_cat_prefix
    case @error_type
    when :syntax_error
      "にゃーん？構文が変だにゃ: "
    when :undefined_variable
      "そんな変数知らないにゃー: "
    when :undefined_function
      "関数が見つからないにゃーん: "
    when :type_error
      "計算できないにゃ！: "
    when :division_by_zero
      "0で割るなんてとんでもないにゃ！: "
    when :argument_error
      "引数が変だにゃ: "
    when :file_error
      "ファイルの問題にゃ: "
    when :lexer_error
      "文字が読めないにゃ: "
    else
      "何かおかしいにゃーん: "
    end
  end
end

class NyanErrorHandler
  CAT_REACTIONS = [
    "にゃーん...",
    "しょんぼりにゃ",
    "困っちゃったにゃ",
    "うーにゃにゃ",
    "どうしようにゃ"
  ].freeze

  def self.handle_error(error)
    puts get_random_reaction
    puts error.message
    
    if ENV['DEBUG']
      puts "\nデバッグ情報:"
      puts error.backtrace
    end
    
    puts "\nヒント: コードを見直してみるにゃ！"
  end

  def self.lexer_error(message, line, column)
    NyanError.new(:lexer_error, message, line, column)
  end

  def self.syntax_error(message, line = nil, column = nil)
    NyanError.new(:syntax_error, message, line, column)
  end

  def self.undefined_variable_error(var_name)
    NyanError.new(:undefined_variable, "#{var_name}")
  end

  def self.undefined_function_error(func_name)
    NyanError.new(:undefined_function, "#{func_name}")
  end

  def self.type_error(message)
    NyanError.new(:type_error, message)
  end

  def self.division_by_zero_error
    NyanError.new(:division_by_zero, "")
  end

  def self.argument_error(message)
    NyanError.new(:argument_error, message)
  end

  def self.file_error(message)
    NyanError.new(:file_error, message)
  end

  private

  def self.get_random_reaction
    CAT_REACTIONS.sample
  end
end