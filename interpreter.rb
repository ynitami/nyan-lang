require_relative 'parser'

# 実行環境 - 変数と関数のスコープを管理する
class Environment
  # 親環境を持つ階層構造で初期化（スコープチェーンを実現）
  def initialize(parent = nil)
    @parent = parent
    @variables = {}
    @functions = {}
  end

  # 変数を定義（現在のスコープに新しい変数を作成）
  def define_variable(name, value)
    @variables[name] = value
  end

  # 変数の値を取得（現在のスコープから親スコープまで順に探索）
  def get_variable(name)
    return @variables[name] if @variables.has_key?(name)
    return @parent.get_variable(name) if @parent
    raise "そんな変数知らないにゃー: #{name}"
  end

  # 既存の変数に値を代入（定義済みの変数をスコープチェーンで探して更新）
  def set_variable(name, value)
    if @variables.has_key?(name)
      @variables[name] = value
    elsif @parent
      @parent.set_variable(name, value)
    else
      raise "そんな変数知らないにゃー: #{name}"
    end
  end

  # 関数を定義（現在のスコープに新しい関数を作成）
  def define_function(name, params, body)
    @functions[name] = { params: params, body: body }
  end

  # 関数の定義を取得（現在のスコープから親スコープまで順に探索）
  def get_function(name)
    return @functions[name] if @functions.has_key?(name)
    return @parent.get_function(name) if @parent
    raise "関数が見つからないにゃーん: #{name}"
  end
end

# return文の値を運ぶ例外クラス - 関数から早期リターンするために使用
class ReturnValue < StandardError
  attr_reader :value

  # return文で返される値を保持
  def initialize(value)
    @value = value
    super()
  end
end

# インタープリター - ASTを実行して結果を得る
class NynLangInterpreter
  # グローバル環境を作成し、現在の実行環境として設定
  def initialize
    @global_env = Environment.new
    @current_env = @global_env
  end

  # ASTを実行してプログラムを動かす（インタープリターのメイン処理）
  def interpret(ast)
    begin
      execute_node(ast)
    rescue ReturnValue => e
      e.value
    end
  end

  private

  # ASTノードを実行して値を返す（各構文要素の実行処理）
  def execute_node(node)
    case node.type
    when :PROGRAM
      result = nil
      node.children.each do |child|
        result = execute_node(child)
      end
      result
    when :VAR_DECLARE
      value = execute_node(node.children[0])
      @current_env.define_variable(node.value, value)
      value
    when :ASSIGNMENT
      value = execute_node(node.children[0])
      @current_env.set_variable(node.value, value)
      value
    when :IDENTIFIER
      @current_env.get_variable(node.value)
    when :NUMBER
      node.value
    when :STRING
      node.value
    when :BOOLEAN
      node.value
    when :BINARY_OP
      execute_binary_operation(node)
    when :PRINT
      value = execute_node(node.children[0])
      # 特別な制御コマンドの処理
      if value.is_a?(String)
        case value
        when "CLEAR_SCREEN"
          print "\e[2J\e[H"
          $stdout.flush
        when "NEWLINE"
          puts
        else
          if value.include?("SLEEP:")
            sleep_time = value.split(":")[1].to_f
            sleep(sleep_time)
          else
            print value
            $stdout.flush
          end
        end
      else
        print value
        $stdout.flush
      end
      value
    when :FUNCTION_DECLARE
      params = node.children[0].children.map { |p| p.value }
      body = node.children[1]
      @current_env.define_function(node.value, params, body)
      nil
    when :FUNCTION_CALL
      execute_function_call(node)
    when :IF
      condition = execute_node(node.children[0])
      if is_truthy(condition)
        execute_node(node.children[1])
      end
    when :WHILE
      result = nil
      while is_truthy(execute_node(node.children[0]))
        result = execute_node(node.children[1])
      end
      result
    when :BLOCK
      result = nil
      node.children.each do |child|
        result = execute_node(child)
      end
      result
    when :RETURN
      value = node.children.empty? ? nil : execute_node(node.children[0])
      raise ReturnValue.new(value)
    when :EXPRESSION_STMT
      execute_node(node.children[0])
    when :ARRAY_LITERAL
      node.children.map { |child| execute_node(child) }
    when :ARRAY_ACCESS
      array = @current_env.get_variable(node.value)
      index = execute_node(node.children[0])
      if array.is_a?(Array) && index.is_a?(Integer) && index >= 0 && index < array.length
        array[index]
      else
        raise "配列アクセスエラーにゃ: #{node.value}[#{index}]"
      end
    when :ARRAY_ASSIGNMENT
      array = @current_env.get_variable(node.value)
      index = execute_node(node.children[0])
      value = execute_node(node.children[1])
      if array.is_a?(Array) && index.is_a?(Integer) && index >= 0 && index < array.length
        array[index] = value
        value
      else
        raise "配列代入エラーにゃ: #{node.value}[#{index}]"
      end
    else
      raise "不明なノードタイプにゃ: #{node.type}"
    end
  end

  # 二項演算（+, -, *, /, ==, != など）を実行
  def execute_binary_operation(node)
    left = execute_node(node.children[0])
    right = execute_node(node.children[1])

    case node.value
    when :PLUS
      if left.is_a?(String) || right.is_a?(String)
        left.to_s + right.to_s
      elsif left.is_a?(Array) && right.is_a?(Array)
        left + right
      else
        left + right
      end
    when :MINUS
      left - right
    when :MULTIPLY
      left * right
    when :DIVIDE
      if right == 0
        raise "0で割ることはできないにゃー"
      end
      left / right
    when :MODULO
      if right == 0
        raise "0で割ることはできないにゃー"
      end
      left % right
    when :EQUAL
      left == right
    when :NOT_EQUAL
      left != right
    when :GREATER
      left > right
    when :LESS
      left < right
    when :GREATER_EQUAL
      left >= right
    when :LESS_EQUAL
      left <= right
    else
      raise "不明な演算子にゃ: #{node.value}"
    end
  end

  # 関数呼び出しを実行（新しいスコープを作って引数を渡し、関数本体を実行）
  def execute_function_call(node)
    function_name = node.value
    args = node.children.map { |arg| execute_node(arg) }

    func_info = @current_env.get_function(function_name)
    params = func_info[:params]
    body = func_info[:body]

    if args.length != params.length
      raise "引数の数が違うにゃ: #{function_name}は#{params.length}個必要にゃ"
    end

    new_env = Environment.new(@current_env)
    params.each_with_index do |param, index|
      new_env.define_variable(param, args[index])
    end

    previous_env = @current_env
    @current_env = new_env

    begin
      result = execute_node(body)
    rescue ReturnValue => e
      result = e.value
    ensure
      @current_env = previous_env
    end

    result
  end

  # 値が真かどうかを判定（条件文で使用）
  def is_truthy(value)
    return false if value.nil?
    return false if value == false
    return false if value == 0
    return false if value == ""
    true
  end
end

# メイン実行部分
if __FILE__ == $0
  if ARGV.length == 0
    puts "使い方: ruby interpreter.rb <ファイル名>"
    exit 1
  end

  filename = ARGV[0]
  begin
    source = File.read(filename, encoding: 'UTF-8')
    lexer = NynLangLexer.new(source)
    tokens = lexer.tokenize
    parser = NynLangParser.new(tokens)
    ast = parser.parse
    interpreter = NynLangInterpreter.new
    interpreter.interpret(ast)
  rescue => e
    puts "エラー: #{e.message}"
    puts e.backtrace if ENV['DEBUG']
  end
end
