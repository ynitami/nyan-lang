#!/usr/bin/env ruby

require_relative 'interpreter'

class NynLang
  def self.run_file(filename)
    unless File.exist?(filename)
      puts "ファイルが見つからないにゃーん: #{filename}"
      exit 1
    end

    source = File.read(filename, encoding: 'utf-8')
    run(source, filename)
  end

  def self.run(source, filename = '<script>')
    begin
      lexer = NynLangLexer.new(source)
      tokens = lexer.tokenize
      
      parser = NynLangParser.new(tokens)
      ast = parser.parse
      
      interpreter = NynLangInterpreter.new
      interpreter.interpret(ast)
    rescue => e
      puts "エラーが発生したにゃ: #{e.message}"
      if ENV['DEBUG']
        puts e.backtrace
      end
      exit 1
    end
  end

  def self.repl
    puts "NynLang（ねこ語）インタプリタにゃーん"
    puts "終了するには 'おしまい' と入力してにゃ"
    puts

    interpreter = NynLangInterpreter.new
    
    loop do
      print "にゃん> "
      input = gets.chomp
      
      break if input == 'おしまい'
      next if input.empty?

      begin
        lexer = NynLangLexer.new(input)
        tokens = lexer.tokenize
        
        parser = NynLangParser.new(tokens)
        ast = parser.parse
        
        result = interpreter.interpret(ast)
        puts "=> #{result}" unless result.nil?
      rescue => e
        puts "にゃーん？: #{e.message}"
      end
    end

    puts "またにゃーん！"
  end
end

if __FILE__ == $0
  if ARGV.length == 0
    NynLang.repl
  elsif ARGV.length == 1
    NynLang.run_file(ARGV[0])
  else
    puts "使い方: ruby nyan.rb [ファイル名.nyan]"
    exit 1
  end
end