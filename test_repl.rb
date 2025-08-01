#!/usr/bin/env ruby

require_relative 'nyan'

# REPLの簡単なテスト
puts "REPLの簡単なテスト"
puts

# いくつかの式を評価してテスト
test_expressions = [
  'ゴロゴロ "テストにゃ"',
  'にゃー x みゃーみゃー 42',
  'ゴロゴロ x',
  'x + 8'
]

interpreter = NynLangInterpreter.new

test_expressions.each do |expr|
  puts "入力: #{expr}"
  begin
    lexer = NynLangLexer.new(expr)
    tokens = lexer.tokenize
    
    parser = NynLangParser.new(tokens)
    ast = parser.parse
    
    result = interpreter.interpret(ast)
    puts "結果: #{result}" unless result.nil?
  rescue => e
    puts "エラー: #{e.message}"
  end
  puts
end