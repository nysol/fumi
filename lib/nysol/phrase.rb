#!/usr/bin/env ruby
# encoding: utf-8

# http://en.wikipedia.org/wiki/Japanese_grammar
# pPhrase: particle phrase : 格助詞句
# dPhrase: declined phrase : 用言句
# sentiment expression(SE) : 評価表現

#$KCODE = "u"
#require "jcode"
require "kconv"
require "nysol/chunk"
require "nysol/token"

module TM
	class ParticlePhrase
		attr_reader :word      # 語
		attr_reader :wordClass # 語のclass2
		attr_reader :particle  # 格助詞

		attr_reader :cid  # この格助詞句のchunkID  # 2010/11/10追加

		# 以下iterationで動的に変化するメンバ変数
		attr_reader :identified # 辞書に登録された用言であるフラグ

		# 第2引数がnilの場合,第1引数をChunkと解釈して初期化する。
		# 両引数がStringであればword,particleと解釈して初期化する。
		def initialize(chunk, p=nil)
			if chunk.class==String then
				@word=chunk
				@particle=p
				@wordClass=nil
			else
				word     = ""
				wordClass= ""
				particle = ""
#puts "ID=====#{chunk.sentence.id}"
				chunk.tokens.each { |token|
#puts "#{token.orgWord} #{token.class2}"
					if token.class2 == "格助詞" or token.class2=="係助詞" then
						particle = token.word
						break
					#elsif token.class1 == "名詞" then # 「評価しない」は、=>「評価は」となってしまう
					else
						if not token.ignoreClass? then
							word += token.orgWord
							wordClass += "#{token.class1}_#{token.class2}:"
						end
					end
				}

#puts "word=#{word}"
				if word!="" and particle!="" then
					particle="が" if particle=="は" or particle=="も"
					@word     = word
					@wordClass= wordClass
					@particle = particle

					@cid      = chunk.id # 2010/11/10追加
				end
			end
		end

		def add(word, particle)
			@word     = word
			@particle = particle
		end

		def to_s
			#return @word+@particle
			return "<#{@word}:#{@particle}>"
		end

		def writeWordClass(fp)
			fp.print @wordClass
		end

		def writeWord(fp)
			fp.print @word
		end

		def writeParticle(fp)
			fp.print @particle
		end

		# 2010/11/10追加
		def writeCid(fp)
			fp.print @cid
		end

		def show(fp=STDERR)
			fp.print "<#{@word}:#{@particle}>"
		end
	end

	class DeclinedPhrase
		attr_reader :phrase

		# 以下iterationで動的に変化するメンバ変数
		attr_reader :identified # 辞書に登録された用言であるフラグ

		def initialize(chunk)
			if chunk.class==String then
				@phrase=chunk
			else
				@phrase=chunk.phrase
			end
		end

		def add(phrase)
			@phrase = phrase
		end

		def to_s
			return @phrase
		end

		def writePhrase(fp)
			fp.print @phrase
		end

		def writePhraseOrg(fp)
			fp.print @phraseOrg
		end

		def show(fp=STDERR)
			fp.print "#{phrase}"
		end
	end
end
