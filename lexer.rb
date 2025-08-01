# トークン（語彙素）を表すクラス - ソースコードを意味のある単位に分割したもの
class Token
  attr_reader :type, :value, :line, :column

  # トークンの種類、値、行番号、列番号を設定
  def initialize(type, value, line = 1, column = 1)
    @type = type
    @value = value
    @line = line
    @column = column
  end

  # デバッグ用の文字列表現
  def to_s
    "Token(#{@type}, #{@value.inspect}, #{@line}:#{@column})"
  end
end

# 字句解析器（レキサー）- ソースコードをトークンに分解する
class NynLangLexer
  KEYWORDS = {
    'にゃー' => :VAR_DECLARE,
    'みゃーみゃー' => :ASSIGN,
    'にゃにゃ' => :FUNCTION_DECLARE,
    'かえるにゃー' => :RETURN,
    'シャー' => :IF,
    'もしゃもしゃ' => :WHILE,
    'ふみふみ' => :BLOCK_START,
    'おわり' => :BLOCK_END,
    'ゴロゴロ' => :PRINT,
    'にゃーん' => :TRUE,
    'ぶーにゃー' => :FALSE
  }.freeze

  OPERATORS = {
    '+' => :PLUS,
    '-' => :MINUS,
    '*' => :MULTIPLY,
    '/' => :DIVIDE,
    '%' => :MODULO,
    '==' => :EQUAL,
    '!=' => :NOT_EQUAL,
    '>' => :GREATER,
    '<' => :LESS,
    '>=' => :GREATER_EQUAL,
    '<=' => :LESS_EQUAL,
    '(' => :LPAREN,
    ')' => :RPAREN,
    ',' => :COMMA,
    '[' => :LBRACKET,
    ']' => :RBRACKET
  }.freeze

  # ソースコードを受け取り、解析の初期状態を設定
  def initialize(source)
    @source = source
    @position = 0
    @line = 1
    @column = 1
    @tokens = []
  end

  # ソースコードをトークンの配列に変換する（字句解析のメイン処理）
  def tokenize
    while @position < @source.length
      case current_char
      when /\s/
        skip_whitespace
      when /[a-zA-Zあ-んア-ンー一-龯]/
        read_identifier_or_keyword
      when /\d/
        read_number
      when '"'
        read_string
      when '#'
        skip_comment
      when '+', '-', '*', '/', '%', '(', ')', ',', '[', ']'
        read_single_char_operator
      when '=', '!', '>', '<'
        read_comparison_operator
      else
        raise_error("にゃーん？この文字は何にゃ: '#{current_char}'")
      end
    end
    
    @tokens << Token.new(:EOF, nil, @line, @column)
    @tokens
  end

  private

  # 現在読んでいる文字を取得
  def current_char
    return nil if @position >= @source.length
    @source[@position]
  end

  # 先読み（現在位置から指定した分だけ先の文字を見る）
  def peek_char(offset = 1)
    pos = @position + offset
    return nil if pos >= @source.length
    @source[pos]
  end

  # 次の文字に進む（行番号・列番号も更新）
  def advance
    if current_char == "\n"
      @line += 1
      @column = 1
    else
      @column += 1
    end
    @position += 1
  end

  # 空白文字（スペース、タブ、改行など）をスキップ
  def skip_whitespace
    while current_char && current_char.match?(/\s/)
      advance
    end
  end

  # コメント（#から行末まで）をスキップ
  def skip_comment
    while current_char && current_char != "\n"
      advance
    end
  end

  # 識別子（変数名など）またはキーワード（にゃーなど）を読み取り
  def read_identifier_or_keyword
    start_pos = @position
    start_column = @column
    value = ""

    while current_char && current_char.match?(/[a-zA-Zあ-んア-ンー一-龯0-9_]/)
      value += current_char
      advance
    end

    token_type = KEYWORDS[value] || :IDENTIFIER
    @tokens << Token.new(token_type, value, @line, start_column)
  end

  # 数値（整数・小数）を読み取り
  def read_number
    start_column = @column
    value = ""
    has_dot = false

    while current_char && (current_char.match?(/\d/) || current_char == '.')
      if current_char == '.'
        if has_dot
          break
        end
        has_dot = true
      end
      value += current_char
      advance
    end

    numeric_value = has_dot ? value.to_f : value.to_i
    @tokens << Token.new(:NUMBER, numeric_value, @line, start_column)
  end

  # 文字列リテラル（"で囲まれた文字列）を読み取り
  def read_string
    start_column = @column
    advance # skip opening quote
    value = ""

    while current_char && current_char != '"'
      if current_char == '\\'
        advance
        case current_char
        when 'n'
          value += "\n"
        when 't'
          value += "\t"
        when '\\'
          value += "\\"
        when '"'
          value += '"'
        when '0'
          # \033 (ESC) の処理
          if peek_char == '3' && peek_char(2) == '3'
            advance # 0
            advance # 3
            advance # 3
            value += "\e"
          else
            value += current_char
          end
        else
          value += current_char
        end
      else
        value += current_char
      end
      advance
    end

    if current_char != '"'
      raise_error("文字列が閉じられてないにゃー")
    end

    advance # skip closing quote
    @tokens << Token.new(:STRING, value, @line, start_column)
  end

  # 単一文字の演算子（+, -, *, / など）を読み取り
  def read_single_char_operator
    op = current_char
    start_column = @column
    advance
    @tokens << Token.new(OPERATORS[op], op, @line, start_column)
  end

  # 比較演算子（==, !=, >=, <= など）を読み取り
  def read_comparison_operator
    start_column = @column
    op = current_char
    advance

    if (op == '=' && current_char == '=') ||
       (op == '!' && current_char == '=') ||
       (op == '>' && current_char == '=') ||
       (op == '<' && current_char == '=')
      op += current_char
      advance
    end

    token_type = OPERATORS[op]
    if token_type.nil?
      raise_error("不明な演算子にゃ: '#{op}'")
    end

    @tokens << Token.new(token_type, op, @line, start_column)
  end

  # エラーメッセージに行番号・列番号を付けて例外を発生
  def raise_error(message)
    raise "#{@line}:#{@column} - #{message}"
  end
end