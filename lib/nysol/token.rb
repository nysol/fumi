#!/usr/bin/env ruby
# encoding: utf-8

# http://en.wikipedia.org/wiki/Japanese_grammar
# particle phrase : 格助詞句
# declined phrase : 用言句
# sentiment expression(SE) : 評価表現

#$KCODE = "u"
#require "jcode"
require "kconv"

module TM
	#
	# 形態素を表すクラス(双方向リスト)
	#
	class Token
		attr_reader :id    # tokenID(文字列)
		attr_reader :word  # 原型語
		attr_reader :orgWord # オリジナル語
		attr_reader :class1
		attr_reader :class2
		attr_reader :class3
		attr_reader :class4
		attr_reader :form1
		attr_reader :form2
		attr_reader :chunk # このtokenが属するchunk
		attr_accessor :next  # 次のtoken
		attr_accessor :prev  # 前のtoken

		# id省略時は終端目的の空tokenとして初期化する。
		#def initialize(id=nil,nxt, prv, word=nil,class1=nil,class2=nil,class3=nil,class4=nil,form1=nil,form2=nil,chunk=nil)
		def initialize(xmlToken, chunk)
			# 双方向リストの設定
 			if chunk.tokens.size>0 then
	      @prev = chunk.tokens.last
			else
	      @prev = chunk.dummy # 終端
			end
      @next = chunk.dummy # 終端
      @prev.next = self if @prev!=nil

			# 各種メンバ変数の設定
			@chunk  = chunk
			if xmlToken==nil then
				@id = nil  # dummy Chunk(双方向リストの終端)
				@word   = ""
				@orgWord= ""
				@class1 = ""
				@class2 = ""
				@class3 = ""
				@class4 = ""
				@form1  = ""
				@form2  = ""
			else
				@id     = xmlToken.attribute("id").to_s
				@word   = xmlToken.attribute("word").to_s
				@orgWord= xmlToken.attribute("orgWord").to_s
				@class1 = xmlToken.attribute("class1").to_s
				@class2 = xmlToken.attribute("class2").to_s
				@class3 = xmlToken.attribute("class3").to_s
				@class4 = xmlToken.attribute("class4").to_s
				@form1  = xmlToken.attribute("form1").to_s
				@form2  = xmlToken.attribute("form2").to_s
			end
		end

		def tokenCsvout(fp)
			fp.print "#{chunk.sentence.article.id},"
			fp.print "#{chunk.sentence.id},"
			fp.print "#{chunk.id},"
			fp.print "#{@id},"
			fp.print "#{chunk.sentence.article.date},"
			fp.print "#{@word},"
			fp.print "#{@orgWord},"
			fp.print "#{@class1},"
			fp.print "#{@class2},"
			fp.print "#{@class3},"
			fp.print "#{@class4},"
			fp.print "#{@form1},"
			fp.print "#{@form2}\n"
		end

		def show(fp=STDERR)
			fp.print "\t\t\tToken id=#{@id}(#{chunk.id})"
			fp.print " #{@word}"      if @word!=""
			fp.print "(#{@orgWord})"  if @orgWord!=""
			fp.print " c1=#{@class1}" if @class1!=""
			fp.print " c2=#{@class2}" if @class2!=""
			fp.print " c3=#{@class3}" if @class3!=""
			fp.print " c4=#{@class4}" if @class4!=""
			fp.print " f1=#{@form1}"  if @form1!=""
			fp.print " f2=#{@form2}"  if @form2!=""
			fp.puts  ""
		end

		# 用言かどうか判定
		def declined?
			return true if class1 == "動詞"
			return true if class1 == "形容詞"
			return true if class1 == "名詞" and class2 == "形容動詞語幹"

			# サ変接続名詞の体言止めは用言とする。
			# 00000001,4,1,2,D,2,消費,消費,名詞,サ変接続,*,*,*,*
			# 00000001,4,1,2,D,3,者,者,名詞,接尾,一般,*,*,*
			# 00000001,4,1,2,D,4,心理,心理,名詞,一般,*,*,*,*
			# 00000001,4,1,2,D,5,も,も,助詞,係助詞,*,*,*,*
			# 00000001,4,2,-1,D,6,急降下,急降下,名詞,サ変接続,*,*,*,*
			# 00000001,4,2,-1,D,7,。,。,記号,句点,*,*,*,*
			return true if class1 == "名詞" and class2 == "サ変接続" and self.next.word == "。"
			return false
		end

		def ignoreClass?()
			return true if ["連体詞", "接頭詞", "接続詞", "助詞", "助動詞", "感動詞", "記号", "フィラー", "その他", "未知語"].index(class1)
			#if class1=="名詞" then
			#	return true if class2=="数"
			#	return true if class2=="固有名詞"
			#end
			return true if word == "*"
			return false
		end
	end
end

if __FILE__ == $0

File.open("xxtra","w"){|file|
file.puts <<DATA
TiD,class
t1,C1
t2,C1
t3,C1
t4,C1
t5,C2
t6,C2
t7,C2
DATA
}
end
