#!/usr/bin/env ruby
# encoding: utf-8

# http://en.wikipedia.org/wiki/Japanese_grammar
# particle phrase : 格助詞句
# declined phrase : 用言句
# sentiment expression(SE) : 評価表現

#$KCODE = "u"
#require "jcode"
require "kconv"
require "nysol/token"
require "nysol/dictionary"

$sign="(—|マイナス)?"
$digit ="([０-９]|[0-9]|[〇一二三四五六七八九]|[十百千万億兆．・]|(ゼロ))"
$num_pfx="(数)?" #数十％
$num_sfx="(数|分)?" #十数％

$pct_num="#{$sign}#{$num_pfx}#{$digit}+#{$num_sfx}"
$pct_pfx="(合計)?"
$pct_sfx ="(台程度|台前半|台後半|相当分|ほど|余り|目前|相当|前後|前半|後半|超え|越え|近く|近辺|規模|未満|以上|以下|以内|程度|台|強|弱|内|幅|分|超)?"
$pct    ="#{$pct_pfx}#{$pct_num}([—〜]#{$pct_num})?％#{$pct_sfx}"

$year_sfx="(いっぱい|上半期|下半期|中ごろ|上期|下期|ごろ|ころ|半ば|時点|年初|後半|前半|当初|当時|以前|以後|以降|以来|初め|前後|初頭|暮れ|途中|通年|通期|期|末|初|内|先|中|春|夏|秋|冬){0,2}"
$year   ="(#{$num_pfx}#{$digit}{1,6}#{$num_sfx}(事務年度|会計年度|年度|年代|年))(#{$year_sfx})"

$syear  ="#{$num_pfx}#{$digit}{1,6}#{$num_sfx}周年"

$stock_pfx="(合計)?"
$stock_sfx="(以上|以下|程度|弱|強|分|超)?"
$stock  ="#{$stock_pfx}#{$num_pfx}#{$digit}+株#{$stock_sfx}"

$cur_pfx="(総額|平均計|平均|累計|給与計|合計約|計約|合計|計|約|累|同)?"
$cur_sfx="(前後|超え|越え|台後半|台前半|程度|規模|前半|超|後半|ほど|近く|余り|未満|近辺|以上|以下|額面|相当分|相当|分|目前|台|強|弱|ずつ|以内|幅)?"
$cur=[]
$currency=["円","ドル","豪ドル","シンガポールドル","台湾ドル","香港ドル","ユーロ","元","ポンド","ウォン"]

def numConv(str)
	a=str.gsub(/#{$pct}/,"XX％")
	a.gsub!(/#{$year}/,"XX年")
	a.gsub!(/#{$syear}/,"XX周年")
	a.gsub!(/#{$stock}/,"XX株")
	$currency.each{|cur|
		a.gsub!(/#{$cur_pfx}#{$pct_num}([—〜]#{$pct_num})?#{cur}#{$cur_sfx}/,"XX#{cur}")
	}
	a.gsub!(/円#{$pct_num}銭/,"円")
	a.gsub!("XX円XX円","XX円")
	return a
end

module TM
	#
	# 文節を表すクラス
	#
	class Chunk
		attr_reader   :id       # 【String】ChunkのID(cabochaが設定したID)
		attr_reader   :linkID   # 【String】係り先chunkのID
		attr_accessor :link     # 【Chunk_Class】係り先のchunkオブジェクト
		attr_accessor :linked   # 【Chunk_Class Array】係り元のchunkオブジェクト配列
		attr_reader   :phrase   # 【String】チャンクのフレーズ(おかしい!!2011/03/02))
		attr_reader   :phraseTok # 【String】チャンクのフレーズ
		attr_reader   :rawPhrase# 【String】助詞など一切省略なしの元チャンク
		attr_reader   :phraseOrg # 【String】チャンクのフレーズ(数字変換前)
		attr_reader   :phraseType # 【String】フレーズタイプ(用言句 or 格助詞句 or nil)
		attr_reader   :caseType # 【String】格助詞 or nil
		attr_reader   :tokens   # 【Token_Class Array】token(形態素)配列 
		attr_reader   :dummy    # 【Token_Class】tokenの双方向リスト用terminal
		attr_reader   :sentence # 【Sentence_Class】このchunkが属するsentence
		attr_reader   :sEntry   # 【SimpleEntry_Class】単純エントリ(なければnil) 
		attr_reader   :cEntries # 【ComplexEntry_Class Array】複合エントリ配列(なければnil)
		attr_reader   :denied   # 【Fixnum】このchunkもしくは係り先のchunkが否定表現であれば-1
		attr_accessor :revPol   # 【Fixnum】逆接接続助詞の相対的反転性(+1 or -1)
		attr_accessor :next     # 【Chunk_Class】双方向リスト次
		attr_accessor :prev     # 【Chunk_Class】双方向リスト前

		# Chunkの各種属性
		attr_reader   :isRevConjunction # 【Bool】逆接接続詞or逆接接続助詞を含むかどうか =>chunkの極性の判定時に利用
		attr_reader   :isConjunction    # 【Bool】接続助詞を含むかどうか=>同定対象chunkの判定時に利用
		attr_reader   :isQuotation      # 【Bool】引用表現であるかどうか =>引用であれば用言句と見なさない
		attr_reader   :isWish           # 【Bool】願望表現であるかどうか
		attr_reader   :isDenial         # 【Bool】否定表現であるかどうか
		attr_reader   :isValidSE        # 【Bool】妥当な評価表現であるかどうか
		attr_reader   :isIdent          # 【Bool】同定対象chunk(entry)かどうか

		#以下動的に決定される属性
		attr_reader   :polarity # 【Fixnum】辞書に登録された用語から導かれる極性(辞書entryの極性+否定や逆接接続を考慮した後の極性)(初期値は0)
		attr_reader   :evalSentenceID # chunk極性を評価する元になった文ID
		attr_reader   :evalChunkID    # chunk極性を評価する元になった文節ID
		attr_reader   :evalPhrase     # chunk極性を評価する元になった文節文字列

		# chunkのpolarityをセットする(同時にpolarityが決まったchunk数カウンタをupする)
		def setPolarity(pol)
			@polarity=pol
		end

		def initialize(xmlChunk, sentence)
			# 双方向リストの設定
			if sentence.chunks.size>0 then
				@prev = sentence.chunks.last
			else
				@prev = sentence.dummy
			end
			@next = sentence.dummy
			@prev.next = self if @prev!=nil

			# 各種メンバ変数設定
			@sentence = sentence
			@tokens = []
			@dummy  = TM::Token.new(nil,self)
			@revPol = 1
			if xmlChunk==nil then
				@id   = nil  # dummy Chunk(双方向リストの終端)
				@linkID = ""
				@tokens << TM::Token.new(nil,self)
			else
				@id   = xmlChunk.attribute("id").to_s
				@linkID = xmlChunk.attribute("link").to_s
				@linked = Array.new
				@phrase = numConv(xmlChunk.attribute("phrase").to_s)
				
				@rawPhrase = numConv(xmlChunk.attribute("rawPhrase").to_s)
				@phraseTok = xmlChunk.attribute("phraseTok").to_s
				@phraseOrg = xmlChunk.attribute("phrase").to_s
#puts "@phraseTok=#{@phraseTok}\t#{@phrase}"
				@phraseType = xmlChunk.attribute("phraseType").to_s
				@caseType   = xmlChunk.attribute("caseType").to_s
				@isQuotation = FALSE
				@isQuotation = TRUE if xmlChunk.attribute("end_of_quotation").to_s=="true"
				@isConditional=FALSE
				@isConditional=TRUE if xmlChunk.attribute("conditional").to_s=="true"
				@isWish = FALSE
				@isWish = TRUE if xmlChunk.attribute("wish").to_s=="true"
				xmlChunk.elements.each("token"){|xmlToken|
					@tokens << TM::Token.new(xmlToken,self)
				}
				@cEntries=[]
				@isIdent=false
			end
			@polarity=0
		end

		def tokenCsvout(fp)
			@tokens.each{|token|
				token.tokenCsvout(fp)
			}
		end

		def phraseCsvout(fp)
			fp.print "#{sentence.article.id},#{sentence.id},#{id},"
			fp.print "\"#{@phraseTok}\"\n"
		end

		def phraseEntryCsvout(fp)
			# 格フレームでない場合
       if phraseType==""
				fp.print "#{sentence.article.id},#{sentence.id},#{id},"
				fp.print ","
				fp.print "\"#{phraseTok}\"\n"

			# 格フレームの場合
			elsif phraseType=="用言句" then
				linked.each{|linkedChunk|
					next if linkedChunk.phraseType!="格助詞句"
					fp.print "#{sentence.article.id},#{sentence.id},#{id},"
					fp.print "#{linkedChunk.caseType},"
					fp.print "\"#{linkedChunk.phraseTok}_#{linkedChunk.caseType} #{phraseTok}_用言\"\n"
				}
			end
		end

		def entryCsvout(fp)
			if phraseType=="用言句" then
				linked.each{|linkedChunk|
					next if linkedChunk.phraseType!="格助詞句"
					fp.print "#{sentence.article.id},#{sentence.id},#{id},"
					fp.print "#{linkedChunk.caseType},"
					fp.print "\"#{linkedChunk.phraseTok}_#{linkedChunk.caseType}\","
					fp.print "\"#{phraseTok}_用言\"\n"
				}
			end
		end

		def show(simple=false, fp=STDERR)
			if simple then
 				@tokens.each{|token|
					fp.print "#{token.word} "
				}
				fp.puts ""
			else
				fp.print "\t\t"
				fp.print "Chunk #{@phraseTok}(#{@phraseType}:#{@caseType}) ATT:rc#{@isRevConjunction ?1:0},cj#{@isConjunction ?1:0},qt#{@isQuotation ?1:0},co#{@isConditional ?1:0},wi#{@isWish ?1:0},de#{@isDenial ?1:0},vs#{@isValidSE ?1:0},id#{@isIdent ?1:0}"
				fp.print " PO#{@polarity},RP#{@revPol}"
				fp.print ",Eval#{@evalSentenceID}-#{@evalChunkID}(#{@evalPhrase})" if @evalSentenceID!=nil
				fp.print " id=#{@id}(#{sentence.id}) to=#{linkID}("
				@linked.each{|chunk| fp.print "#{chunk.id},"}
				fp.print ") "
				@sEntry.show(fp) if @sEntry!=nil
				if @cEntries!=nil then
					@cEntries.each{|cEntry|
						fp.print " "
						cEntry.show(fp)
					}
				end
				fp.puts ""
 				@tokens.each{|token|
					token.show(fp)
				}
			end
		end

		def phraseD
			# チャンクの否定語付きフレーズの設定
			if @isDenial then
				return @phraseTok+":否"
			else
				return @phraseTok
			end
		end

		# ======================================================
		# chunkに関する各種属性を調べ、それぞれの判定メンバ変数にbool値をセットする
		# ======================================================
		def setAttributes
			return false if @tokens.size==0

			# 後ろ二つのtokenをセット
			token1=token2=@dummy
			endByTokusyu=false
			i=0
			@tokens.reverse.each {|token|
				if token.class1 == "特殊" then # 句読点
					endByTokusyu=true if i==0
					i+=1
					next
				end
				token1 = token
				token2 = token.prev
				break
			}

			# 否定であるかどうか
			@isDenial=FALSE
			dFlg=1
			@tokens.each {|token|
				if (token.class1=="接尾辞" and (token.word=="ない" or token.word=="ぬ" or token.word=="ん" or token.word=="かねる")) or (token.class1=="形容詞" and token.word=="ない") or (token.class1=="助動詞" and token.word=="ぬ") then
					dFlg *= -1
				end
			}
			@isDenial=TRUE  if dFlg==-1

			# 逆接接続詞かどうか
			@isRevConjunction=false
			if (token1.class1=="接続詞" or token1.class2=="接続助詞") and ["一方","しかし","しかしながら","ところが","それでいて","なのに","それどころか","が","だが","けれども","けれど","ながら","ものの"].index(token1.word) then
				@isRevConjunction=true
			elsif token1.orgWord=="の" and token2.orgWord=="もの" then
				@isRevConjunction=true
			elsif token1.orgWord=="も" and token2.orgWord=="ながら" then
				@isRevConjunction=true
			elsif token1.orgWord=="のに" and token1.class1=="助動詞" and endByTokusyu then
				@isRevConjunction=true
			elsif token1.orgWord=="のに" and token2.orgWord=="な" then
				@isRevConjunction=true
			elsif token1.orgWord=="対し" and token2.word=="に" then
				@isRevConjunction=true
			elsif token1.word.index("にもかかわらず") and token1.class1=="接続詞" then
				@isRevConjunction=true
			elsif token1.orgWord=="ず" and token2.orgWord=="かかわら" then
				@isDenial=false
				@isRevConjunction=true
			end

			# 接続詞かどうか
			@isConjunction=false
			@isConjunction=true  if token1.class2=="接続助詞"
	
			# 引用の用言であるかどうか(直前のchunkの最後のwordが引用格助詞かどうかを判定する)
			# ex.
			# 三越伊勢丹ホールディングスの石塚邦雄社長は「最悪な景気感が二年は続くと思って経営にあたる」という。
			# 続く「と」思って,「と」いう。
			#@isQuotation=false
			#@isQuotation=true if @prev.tokens.last.class2=="格助詞" and @prev.tokens.last.class3=="引用"

			# 仮定形のchunkかどうか
			# 例1)
			# する,する,動詞,自立,*,*,サ変・スル,基本形
			# なら,だ,助動詞,*,*,*,特殊・ダ,仮定形
			# 例2)
			# 増やせ,増やす,動詞,自立,*,*,五段・サ行,仮定形
			# ば,ば,助詞,接続助詞,*,*,*,*
			#@isConditional=false
			#@isConditional=true if  token1.form2=="仮定形" and (token1.orgWord=="なら" || token1.orgWord=="たら")
			#@isConditional=true if  token2.form2=="仮定形" and (token1.word=="ば"      || token1.word=="と")

			# 願望のchunkかどうか
			# 怠ら,怠る,動詞,自立,*,*,五段・ラ行,未然形
			# ない,ない,助動詞,*,*,*,特殊・ナイ,基本形
			# よう,よう,名詞,非自立,助動詞語幹,*,*,*
			# に,に,助詞,格助詞,一般,*,*,*
			# し,する,動詞,自立,*,*,サ変・スル,連用形
			# たい,たい,助動詞,*,*,*,特殊・タイ,基本形
			# 。,。,記号,句点,*,*,*,*
			#@isWish=false
			#@isWish=true if token2.form2=="連用形" and token1.word=="たい"
			#@isWish=true if token2.class1=="接尾辞" and token1.word=="ほしい"

			# chunkが評価表現の同定対象として有効かどうか
			@isValidSE = true
			@isValidSE = false if @sEntry==nil or @isConditional or @isWish
		end

		# ======================================================
		# chunkが用言句であればEntry(極性は0)を登録する。
		# ======================================================
		def setEntry
			return if @phraseType!="用言句"
			dPhrase = DeclinedPhrase.new(self)
			@sEntry = SimpleEntry.new(dPhrase,0)
			@linked.each{|from|
				pPhrase = ParticlePhrase.new(from)
				next nil if pPhrase.word==nil
				@cEntries << ComplexEntry.new(dPhrase,pPhrase,0)
			}
			return true
		end

		# ======================================================
		# 同定対象chunkかどうかを判定し、isIdent変数をセットする
		# ======================================================
		def setIdentChunk
			return if @id==nil

			#「〜と思う。」などの引用表現の場合は、一つ前の用言句を対象とする。
			if isQuotation then
				@isIdent=false
				prev.setIdentChunk
				return
			end

			if isValidSE then
				@isIdent=true
			else
				@isIdent=false
			end

			@isIdent=true
			@linked.each{|from|
				if from.isConjunction then
					from.setIdentChunk
				end
			}
		end

		# ============================================================================
		# chunkを後方にたどってchunkのpolarityを設定する。
		# 既にpolarityが設定済みであればそれ以降は何も設定せずに戻ってくる。
		# 逆接接続詞に出会えば、次のchunkから極性を反転させる ex. AAA(+1) BBBだが(+1) CCC(-1)
		def evalPolNext(polarity)
			return if @id==nil
			return if @polarity!=0
			setPolarity(polarity)
			nextPol = polarity
			nextPol *= (-1) if @isRevConjunction # 逆接接続詞の場合は極性反転
			@next.evalPolNext(nextPol)
			return
		end

		# chunkを前方にたどってchunkのpolarityを設定する。
		def evalPolPrev(polarity)
			return if @id==nil
			return if @polarity!=0
			setPolarity(polarity)
			@polarity *= (-1) if @isRevConjunction # 逆接接続詞の場合は極性反転
			@prev.evalPolPrev(@polarity)
			return
		end

		# 辞書に登録されているエントリとその辞書上のpolarityから計算される##sentence##のpolarityを返す
		def getSentencePol(dic)
			pols=Array.new
			ents=Array.new
			return pols,ents if @sEntry==nil          # 用言句でない
			return pols,ents if not @isIdent          # 対象用言句でない
			return pols,ents if @sentence.mChunk==nil # 主節がない

			# 単純エントリ
			dsEntry=dic.find(@sEntry)                 # 辞書検索
			if dsEntry!=nil then
				# 記事におけるentryのiterNoと極性更新
				if @sEntry.iterNo==-1 then
					@sEntry.iterNo   = dsEntry.iterNo
					@sEntry.polarity = dsEntry.polarity
				end

				# 文極性判定(主節の極性を調べる)
				# ....株価は下降していないが、.....景気は悪化している。
				#                   isDenial
				# ....株価は上昇しているが、.....景気は悪化している。
				#         @revPol=+1    ~~          @revPol=-1
				sPol =dsEntry.polarity                         # 辞書極性
				sPol*=-1 if isDenial                           # そのchunkが否定なら極性反転
				sPol*=-1 if @sentence.mChunk.revPol != @revPol # 主節のchunkの接続詞関係について極性が一致しなければ極性反転
				# 登録
				ents << dsEntry
				pols << sPol
			end

			# 複合エントリ
			@cEntries.each{|cEntry|
				dcEntry=dic.find(cEntry)
				if dcEntry!=nil then
					# 記事におけるentryのiterNoと極性更新
					if cEntry.iterNo==-1 then
						cEntry.iterNo   = dcEntry.iterNo
						cEntry.polarity = dcEntry.polarity
					end

					# 文極性判定
					cPol=dcEntry.polarity
					cPol*=-1 if isDenial
					cPol*=-1 if @sentence.mChunk.revPol != @revPol
					# 登録
					ents << dcEntry
					pols << cPol
				end
			}
			return pols,ents
		end

		#==========================================================
		# 候補辞書candにentryを@polarity極性にて登録する。
		# 015_gendic->sentence.setCandidateから呼ばれる
		#==========================================================
		def setCandidate(cand)
			return if @sEntry==nil     # 用言句でない
			return if not @isIdent     # 同定対象用言句でない

			# 以下の一文は、MP対応にするまではコメントアウトしていたが復活させた。
			# コメントアウトしていた理由は、トータル件数をカウントするためである。
			# ただ、その為に全エントリが候補としてあがることになり、非常に効率が悪かった。
			# そこで、トータル件数は別の場所(genDic.rb)でセットすることでこの問題を回避することとした。
			return if @polarity==0     # chunk極性が評価されていない

			# 以下をコメントアウトするのは、辞書に既に登録されているエントリも候補として処理するため。
#			return if @sEntry.polarity!=0 # このchunkのpolarityが評価済み

			pol=@polarity
			pol*=(-1) if @isDenial

			cand.add(@sEntry,pol)
			@cEntries.each{|cEntry|
				cand.add(cEntry,pol)
			}
		end

		def words
			result = ""
			@tokens.each do |token|
				result += token.word
			end
			return result
		end

		# 助詞、助動詞、句点を除いたコア語を得る
		def coreWords(prohibit=[])
			prefixVerb=TRUE
			result = ""
			@tokens.each do |token|
				if token.class1=="名詞" then
					prefixVerb=FALSE
				end
				c1=["助詞","助動詞","記号","接頭詞"].index(token.class1)==nil
				c2=["句点","読点","非自立"]         .index(token.class2)==nil
				c3=(token.class1!="動詞" or prefixVerb)

				c4=(prohibit.index(token.word)==nil)
#puts "       #{c1} #{c2} #{c3} #{c4} #{token.word} #{token.class1} #{token.class2}"
				if c1 and c2 and c3 and c4 then
					if token.word=="" then
						result += token.orgWord
					else
						result += token.word
					end
				end
			end
			result = result.chomp.strip.gsub(",","_")
			
			return result
		end

	end
end

