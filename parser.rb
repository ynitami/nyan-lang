require_relative 'lexer'

# 抽象構文木（AST）のノード - プログラムの構造を木構造で表現する
class ASTNode
  attr_reader :type, :value, :children

  # ノードのタイプ、値、子ノードを設定
  def initialize(type, value = nil, children = [])
    @type = type
    @value = value
    @children = children
  end

  # デバッグ用の木構造表示
  def to_s(indent = 0)
    result = "  " * indent + "#{@type}"
    result += "(#{@value})" if @value
    result += "\n"
    @children.each do |child|
      result += child.to_s(indent + 1)
    end
    result
  end
end

# 構文解析器（パーサー）- トークン列を抽象構文木（AST）に変換する
class NynLangParser
  # トークン配列を受け取り、解析の初期状態を設定
  def initialize(tokens)
    @tokens = tokens
    @position = 0
  end

  # 全トークンを解析してプログラム全体のASTを生成（構文解析のメイン処理）
  def parse
    statements = []
    while !at_end?
      stmt = parse_statement
      statements << stmt if stmt
    end
    ASTNode.new(:PROGRAM, nil, statements)
  end

  private

  # 現在解析しているトークンを取得
  def current_token
    return nil if @position >= @tokens.length
    @tokens[@position]
  end

  # 先読み（現在位置から指定した分だけ先のトークンを見る）
  def peek_token(offset = 1)
    pos = @position + offset
    return nil if pos >= @tokens.length
    @tokens[pos]
  end

  # 次のトークンに進む
  def advance
    @position += 1 unless at_end?
  end

  # 全トークンを解析し終わったかチェック
  def at_end?
    current_token.nil? || current_token.type == :EOF
  end

  # 現在のトークンが指定されたタイプのいずれかと一致するかチェック
  def match(*types)
    return false if at_end?
    types.include?(current_token.type)
  end

  # 指定されたタイプのトークンを消費（期待するトークンでなければエラー）
  def consume(type, message)
    if match(type)
      token = current_token
      advance
      return token
    end
    raise_error(message)
  end

  # 文（変数宣言、代入、関数宣言など）を解析
  def parse_statement
    case current_token&.type
    when :VAR_DECLARE
      parse_variable_declaration
    when :IDENTIFIER
      if peek_token&.type == :ASSIGN
        parse_assignment
      elsif peek_token&.type == :LBRACKET
        # Check if it's array assignment: identifier[index] = value
        name = current_token.value
        advance
        advance  # consume '['
        index = parse_expression
        consume(:RBRACKET, "']'が必要にゃ")
        if match(:ASSIGN)
          advance  # consume '='
          value = parse_expression
          ASTNode.new(:ARRAY_ASSIGNMENT, name, [index, value])
        else
          # It's just array access, treat as expression
          array_access = ASTNode.new(:ARRAY_ACCESS, name, [index])
          ASTNode.new(:EXPRESSION_STMT, nil, [array_access])
        end
      else
        parse_expression_statement
      end
    when :FUNCTION_DECLARE
      parse_function_declaration
    when :IF
      parse_if_statement
    when :WHILE
      parse_while_statement
    when :PRINT
      parse_print_statement
    when :RETURN
      parse_return_statement
    else
      parse_expression_statement
    end
  end

  # 変数宣言（にゃー x みゃーみゃー 値）を解析
  def parse_variable_declaration
    advance # consume 'にゃー'
    name = consume(:IDENTIFIER, "変数名が必要にゃ").value
    consume(:ASSIGN, "'みゃーみゃー'が必要にゃ")
    value = parse_expression
    ASTNode.new(:VAR_DECLARE, name, [value])
  end

  # 変数代入（x みゃーみゃー 値）を解析
  def parse_assignment
    name = current_token.value
    advance # consume identifier
    consume(:ASSIGN, "'みゃーみゃー'が必要にゃ")
    value = parse_expression
    ASTNode.new(:ASSIGNMENT, name, [value])
  end

  # 関数宣言（にゃにゃ 関数名(引数) ふみふみ...おわり）を解析
  def parse_function_declaration
    advance # consume 'にゃにゃ'
    name = consume(:IDENTIFIER, "関数名が必要にゃ").value
    consume(:LPAREN, "'('が必要にゃ")
    
    params = []
    while !match(:RPAREN) && !at_end?
      params << consume(:IDENTIFIER, "パラメータ名が必要にゃ").value
      if match(:COMMA)
        advance
      elsif !match(:RPAREN)
        raise_error("','か')'が必要にゃ")
      end
    end
    
    consume(:RPAREN, "')'が必要にゃ")
    consume(:BLOCK_START, "'ふみふみ'が必要にゃ")
    
    body = []
    while !match(:BLOCK_END) && !at_end?
      stmt = parse_statement
      body << stmt if stmt
    end
    
    consume(:BLOCK_END, "'おわり'が必要にゃ")
    
    param_nodes = params.map { |p| ASTNode.new(:PARAMETER, p) }
    body_node = ASTNode.new(:BLOCK, nil, body)
    ASTNode.new(:FUNCTION_DECLARE, name, [ASTNode.new(:PARAMETERS, nil, param_nodes), body_node])
  end

  # if文（シャー 条件 ふみふみ...おわり）を解析
  def parse_if_statement
    advance # consume 'シャー'
    condition = parse_expression
    consume(:BLOCK_START, "'ふみふみ'が必要にゃ")
    
    then_body = []
    while !match(:BLOCK_END) && !at_end?
      stmt = parse_statement
      then_body << stmt if stmt
    end
    
    consume(:BLOCK_END, "'おわり'が必要にゃ")
    
    condition_node = condition
    body_node = ASTNode.new(:BLOCK, nil, then_body)
    ASTNode.new(:IF, nil, [condition_node, body_node])
  end

  # while文（もしゃもしゃ 条件 ふみふみ...おわり）を解析
  def parse_while_statement
    advance # consume 'もしゃもしゃ'
    condition = parse_expression
    consume(:BLOCK_START, "'ふみふみ'が必要にゃ")
    
    body = []
    while !match(:BLOCK_END) && !at_end?
      stmt = parse_statement
      body << stmt if stmt
    end
    
    consume(:BLOCK_END, "'おわり'が必要にゃ")
    
    condition_node = condition
    body_node = ASTNode.new(:BLOCK, nil, body)
    ASTNode.new(:WHILE, nil, [condition_node, body_node])
  end

  # print文（ゴロゴロ 式）を解析
  def parse_print_statement
    advance # consume 'ゴロゴロ'
    expression = parse_expression
    ASTNode.new(:PRINT, nil, [expression])
  end

  # return文（かえるにゃー 式）を解析
  def parse_return_statement
    advance # consume 'かえるにゃー'
    expression = parse_expression
    ASTNode.new(:RETURN, nil, [expression])
  end

  # 式文（式だけの行）を解析
  def parse_expression_statement
    expr = parse_expression
    ASTNode.new(:EXPRESSION_STMT, nil, [expr])
  end

  # 式全体を解析（比較演算から開始）
  def parse_expression
    parse_comparison
  end

  # 比較演算（==, !=, >, <, >=, <=）を解析
  def parse_comparison
    expr = parse_addition

    while match(:EQUAL, :NOT_EQUAL, :GREATER, :LESS, :GREATER_EQUAL, :LESS_EQUAL)
      operator = current_token.type
      advance
      right = parse_addition
      expr = ASTNode.new(:BINARY_OP, operator, [expr, right])
    end

    expr
  end

  # 加算・減算（+, -）を解析
  def parse_addition
    expr = parse_multiplication

    while match(:PLUS, :MINUS)
      operator = current_token.type
      advance
      right = parse_multiplication
      expr = ASTNode.new(:BINARY_OP, operator, [expr, right])
    end

    expr
  end

  # 乗算・除算・剰余（*, /, %）を解析
  def parse_multiplication
    expr = parse_primary

    while match(:MULTIPLY, :DIVIDE, :MODULO)
      operator = current_token.type
      advance
      right = parse_primary
      expr = ASTNode.new(:BINARY_OP, operator, [expr, right])
    end

    expr
  end

  # 基本的な式（数値、文字列、変数、関数呼び出しなど）を解析
  def parse_primary
    case current_token&.type
    when :NUMBER
      value = current_token.value
      advance
      ASTNode.new(:NUMBER, value)
    when :STRING
      value = current_token.value
      advance
      ASTNode.new(:STRING, value)
    when :TRUE
      advance
      ASTNode.new(:BOOLEAN, true)
    when :FALSE
      advance
      ASTNode.new(:BOOLEAN, false)
    when :IDENTIFIER
      name = current_token.value
      advance
      if match(:LPAREN)
        parse_function_call(name)
      elsif match(:LBRACKET)
        parse_array_access(name)
      else
        ASTNode.new(:IDENTIFIER, name)
      end
    when :LBRACKET
      parse_array_literal
    when :LPAREN
      advance
      expr = parse_expression
      consume(:RPAREN, "')'が必要にゃ")
      expr
    else
      raise_error("予期しないトークンにゃ: #{current_token&.type}")
    end
  end

  # 関数呼び出し（関数名(引数1, 引数2, ...)）を解析
  def parse_function_call(name)
    consume(:LPAREN, "'('が必要にゃ")
    
    args = []
    while !match(:RPAREN) && !at_end?
      args << parse_expression
      if match(:COMMA)
        advance
      elsif !match(:RPAREN)
        raise_error("','か')'が必要にゃ")
      end
    end
    
    consume(:RPAREN, "')'が必要にゃ")
    
    arg_nodes = args
    ASTNode.new(:FUNCTION_CALL, name, arg_nodes)
  end

  # 配列リテラル（[要素1, 要素2, ...]）を解析
  def parse_array_literal
    advance  # consume '['
    
    elements = []
    while !match(:RBRACKET) && !at_end?
      elements << parse_expression
      if match(:COMMA)
        advance
      elsif !match(:RBRACKET)
        raise_error("','か']'が必要にゃ")
      end
    end
    
    consume(:RBRACKET, "']'が必要にゃ")
    ASTNode.new(:ARRAY_LITERAL, nil, elements)
  end

  # 配列アクセス（配列名[インデックス]）を解析
  def parse_array_access(array_name)
    advance  # consume '['
    index = parse_expression
    consume(:RBRACKET, "']'が必要にゃ")
    ASTNode.new(:ARRAY_ACCESS, array_name, [index])
  end

  # エラーメッセージにトークンの位置情報を付けて例外を発生
  def raise_error(message)
    token = current_token
    if token
      raise "#{token.line}:#{token.column} - #{message}"
    else
      raise "EOF - #{message}"
    end
  end
end