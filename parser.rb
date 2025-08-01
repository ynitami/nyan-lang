require_relative 'lexer'

class ASTNode
  attr_reader :type, :value, :children

  def initialize(type, value = nil, children = [])
    @type = type
    @value = value
    @children = children
  end

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

class NynLangParser
  def initialize(tokens)
    @tokens = tokens
    @position = 0
  end

  def parse
    statements = []
    while !at_end?
      stmt = parse_statement
      statements << stmt if stmt
    end
    ASTNode.new(:PROGRAM, nil, statements)
  end

  private

  def current_token
    return nil if @position >= @tokens.length
    @tokens[@position]
  end

  def peek_token(offset = 1)
    pos = @position + offset
    return nil if pos >= @tokens.length
    @tokens[pos]
  end

  def advance
    @position += 1 unless at_end?
  end

  def at_end?
    current_token.nil? || current_token.type == :EOF
  end

  def match(*types)
    return false if at_end?
    types.include?(current_token.type)
  end

  def consume(type, message)
    if match(type)
      token = current_token
      advance
      return token
    end
    raise_error(message)
  end

  def parse_statement
    case current_token&.type
    when :VAR_DECLARE
      parse_variable_declaration
    when :IDENTIFIER
      if peek_token&.type == :ASSIGN
        parse_assignment
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

  def parse_variable_declaration
    advance # consume 'にゃー'
    name = consume(:IDENTIFIER, "変数名が必要にゃ").value
    consume(:ASSIGN, "'みゃーみゃー'が必要にゃ")
    value = parse_expression
    ASTNode.new(:VAR_DECLARE, name, [value])
  end

  def parse_assignment
    name = current_token.value
    advance # consume identifier
    consume(:ASSIGN, "'みゃーみゃー'が必要にゃ")
    value = parse_expression
    ASTNode.new(:ASSIGNMENT, name, [value])
  end

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

  def parse_print_statement
    advance # consume 'ゴロゴロ'
    expression = parse_expression
    ASTNode.new(:PRINT, nil, [expression])
  end

  def parse_return_statement
    advance # consume 'かえるにゃー'
    expression = parse_expression
    ASTNode.new(:RETURN, nil, [expression])
  end

  def parse_expression_statement
    expr = parse_expression
    ASTNode.new(:EXPRESSION_STMT, nil, [expr])
  end

  def parse_expression
    parse_comparison
  end

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

  def parse_multiplication
    expr = parse_primary

    while match(:MULTIPLY, :DIVIDE)
      operator = current_token.type
      advance
      right = parse_primary
      expr = ASTNode.new(:BINARY_OP, operator, [expr, right])
    end

    expr
  end

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
      else
        ASTNode.new(:IDENTIFIER, name)
      end
    when :LPAREN
      advance
      expr = parse_expression
      consume(:RPAREN, "')'が必要にゃ")
      expr
    else
      raise_error("予期しないトークンにゃ: #{current_token&.type}")
    end
  end

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

  def raise_error(message)
    token = current_token
    if token
      raise "#{token.line}:#{token.column} - #{message}"
    else
      raise "EOF - #{message}"
    end
  end
end