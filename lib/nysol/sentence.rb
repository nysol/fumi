#!/usr/bin/env ruby
# encoding: utf-8

require "nysol/chunk"
require "nysol/phrase"

# http://en.wikipedia.org/wiki/Japanese_grammar
# particle phrase : 格助詞句
# declined phrase : 用言句
# sentiment expression(SE) : 評価表現

#$KCODE = "u"
#require "jcode"
require "kconv"

module TM
	#
	# 文を表すクラス
	#
	class Sentence
		attr_reader   :id
		attr_reader   :text
		attr_reader   :article
		attr_reader   :chunks
		attr_reader   :entryChunks  # Entryを含む全chunk
		#attr_reader   :dChunksIdent # 同定用用言chunkへの参照配列
		attr_reader   :mChunk       # この文の主節chunk
		attr_reader   :startByRevConjunction # この文が逆接接続詞で始まっているかどうか
		attr_reader   :dummy
		attr_reader   :isQuestion
		attr_accessor :next
		attr_accessor :prev

		attr_reader   :polarity #文全体としての極性

		#==========================================================
		# 初期化
		#==========================================================
		def initialize(xmlSentence,article)
			#----------------------------------
			# 双方向リストの設定
			if article.sentences.size>0 then
				@prev = article.sentences.last
			else	
				@prev = article.dummy
			end
			@next = article.dummy
			@prev.next = self if @prev!=nil

			#----------------------------------
			# 各種メンバ変数の設定
			@article = article
			@chunks = []
			@dummy  = TM::Chunk.new(nil,self)
			if xmlSentence==nil then
				@id = nil  # Articleにおけるdummy Sentence(双方向リストの終端)
				return
			else
				@id     = xmlSentence.attribute("id").to_s
				@text   = xmlSentence.attribute("text").to_s
				xmlSentence.elements.each("chunk"){|xmlChunk|
					@chunks << TM::Chunk.new(xmlChunk,self)
				}
				@entryChunks = []
				#@dChunksIdent = [] # 同定用用言句を含むchunk
				@polarity=0

				@evalPols=Array.new
				@evalEnts=Array.new
				@evalCids=Array.new
			end

			# 130スクリプトでparse失敗時(ex.長過ぎる文章)は、chunkサイズは0なので何もせずリターン
			return if @chunks.size == 0

			#----------------------------------
			# 疑問文かどうか
			@isQuestion=false
			@isQuestion=true if @chunks.last.tokens.last.word == "？"
			@isQuestion=true if @chunks.last.tokens.last.word == "。" and @chunks.last.tokens.last.prev.word == "か"
	
			#----------------------------------
			# chunkのlink(係り先chunk)をID(文字列)からchunkオブジェクトに変更
			# chunkのlined(係り元)chunkオブジェクトを登録
			@chunks.each{|from|
				from.link = @dummy if from.linkID=="-1" 
				@chunks.each{|to|
					if from.linkID == to.id then
						from.link = to
						to.linked << from
						break
					end
				}
			}

			#----------------------------------
			# Entry用言句であれば用言句,格助詞句+用言句を作成
			@chunks.each{|chunk|
				if chunk.setEntry then
					@entryChunks << chunk
				end
			}

			#----------------------------------
			# chunkに関する各種属性を設定する
			@chunks.each{|chunk|
				chunk.setAttributes
			}

			#----------------------------------
			# 逆接接続詞による極性反転フラグを設定
			# 1. 株価は上昇しているが、景気は悪化している。
			# 2. 株価は上昇しているが、景気は回復していない。
			# 3. 株価は下降はしていないが、景気は悪化している。
			# 4. 株価は下降はしていないが、景気は回復していない。
			if @chunks.size>0 then
				@chunks[0].revPol=1
				1.upto(@chunks.size-1){|i|
					if @chunks[i-1].isRevConjunction then # 前chunkが逆接接続詞なら反転
						@chunks[i].revPol = @chunks[i-1].revPol * (-1)
					else                                  # 前chunkが逆接接続詞でないなら前chunkの極性を引き継ぐ
						@chunks[i].revPol = @chunks[i-1].revPol
					end
				}
			end

			#----------------------------------
			# 否定語を伴うchunkもしくは否定語に係るchunkであればdeniedに-1をセットする。
			@chunks.each{|chunk|
				@denied=1
				if chunk.isDenial then
					@denied = -1
				end
				@denied = -1 if chunk.link.isDenial
			}

			#----------------------------------
			# 同定対象用言に印を付ける
			@chunks.last.setIdentChunk

			#----------------------------------
			# 主節(文の最後の用言chunk)
			@chunks.reverse.each{|chunk|
				if chunk.isIdent then
					@mChunk=chunk
					break
				end
			}

			#----------------------------------
			# 逆接接続詞から始まるかどうか
			@startByRevConjunction=false
			@startByRevConjunction=true  if @chunks.first.isRevConjunction
		end

		#----------------------------------------------------------
		# 文極性配列(pols)-辞書エントリ配列(ents)から文書極性を評価する
		#----------------------------------------------------------
		def vote(pols,ents)
			# 該当する辞書エントリが一つだけであれば、対応する文極性を返す。
			# 多くの場合は、ここで決まる。
			return pols[0] if pols.size==1

			# pos,negの数を計算し、多い方の極性とする。
			pos=neg=0
			pols.each{|pol|
				if pol==1 then
					pos+=1
				else
					neg+=1
				end
			}
			if    pos>neg then
				return +1
			elsif neg>pos then
				return -1

			# 投票で決まらない場合は、辞書の登録順とする。
			# それで決まらなければ配列要素番号の若いentryとする。
			else
				minNo=99999
				minI =0
				(0...ents.size).each{|i|
					no=ents[i].iterNo
					if minNo>no then
						minNo=no
						minI =i
					end
				}
				return pols[minI]
			end
		end

		#----------------------------------------------------------
		# 辞書に登録されたEntryを含むchunkを検索し、あればchunkEntryの極性を更新する
		# 文の極性(主節(文末のchunk)の極性)を返す。
		# 辞書に登録がなければ0を返す。
		#----------------------------------------------------------
		def evalPol(dic)
			evalPols=[]
			evalEnts=[]
			evalCids=[]
			@entryChunks.each{|chunk|
				next if not chunk.isIdent
				# chunkがdicに含まれているかを調べ、含まれていれば##文の極性##および辞書上のentoryを得る
				pols,ents = chunk.getSentencePol(dic)
				(0...pols.size).each{|i|
					evalPols << pols[i]
					evalEnts << ents[i]
					evalCids << chunk.id
				}
			}
			# 投票により文の極性を決定する
			polarity=0
			polarity=vote(evalPols,evalEnts) if evalPols.size>0

			return polarity, evalPols, evalEnts, evalCids
		end

		def updateFromHead(pol, evalPols,evalEnts,evalCids,evalSid)
			return if @polarity!=0 # 評価済みならなにもしない
			@polarity=pol
			@evalPols=evalPols
			@evalEnts=evalEnts
			@evalCids=evalCids
			@evalSid =evalSid
			@chunks.first.evalPolNext(pol)
		end

		def updateFromTail(pol, evalPols,evalEnts,evalCids,evalSid)
			return if @polarity!=0 # 評価済みならなにもしない
			@polarity=pol
			@evalPols=evalPols
			@evalEnts=evalEnts
			@evalCids=evalCids
			@evalSid =evalSid
			@chunks.last.evalPolPrev(pol)
		end

		# 候補辞書candに以下のentryを追加する。
		# 1. 文中で極性の付いたchunkで、かつentryは極性が付いていないものはchunk極性として追加
		def setCandidate(cand)
			@entryChunks.each{|chunk|
				chunk.setCandidate(cand)
			}
		end

		def tokenCsvout(fp)
			@chunks.each{|chunk|
				chunk.tokenCsvout(fp)
			}
		end

		def phraseCsvout(fp)
			@chunks.each{|chunk|
				chunk.phraseCsvout(fp)
			}
		end

		def phraseEntryCsvout(fp)
			@chunks.each{|chunk|
				chunk.phraseEntryCsvout(fp)
			}
		end

		def entryCsvout(fp)
			@chunks.each{|chunk|
				chunk.entryCsvout(fp)
			}
		end

		# 文章のcorpusとcaseFrame情報を返す
		#
		def caseFrame
			caseFrames=[]
			outChunk=[]
			@chunks.each{|chunk|
				advConj=""
				advConj=-1 if chunk.isRevConjunction # 逆接続詞
				denial = 1
				denial =-1 if chunk.isDenial
				if chunk.phraseType=="用言句" then
					cf=Hash.new
					cf["aid"]     = @article.id
					cf["sid"]     = @id
					cf["cid"]     = chunk.id
					cf["cfFlag"]  = 1
					cf["advConj"] = advConj
					cf["denial"]  = denial

					terms=[]
					terms << [chunk.phraseTok,"用言"]
					outChunk << chunk.id
					chunk.linked.each{|linkedChunk|
						if linkedChunk.phraseType=="格助詞句" and linkedChunk.caseType!="修飾格" and linkedChunk.caseType!="時間格" then
							terms << [linkedChunk.phraseTok,linkedChunk.caseType]
							outChunk << linkedChunk.id
						end
					}
					cf["terms"] = terms

					caseFrames << cf
				end
			}

			# 格フレーム以外の出力
			@chunks.each{|chunk|
				advConj=""
				advConj=-1 if chunk.isRevConjunction # 逆接続詞
				denial = 1
				denial =-1 if chunk.isDenial

				if outChunk.index(chunk.id)==nil then
					cf=Hash.new
					cf["aid"]     = @article.id
					cf["sid"]     = @id
					cf["cid"]     = chunk.id
					cf["cfFlag"]  = 0
					cf["advConj"] = advConj
					cf["denial"]  = denial

					terms=[]
					terms << [chunk.phraseTok,"OTHER"]
					cf["terms"] = terms

					caseFrames << cf
				end
			}

			return caseFrames
		end

		def show(simple=false,fp=STDERR)
			if simple then
				fp.puts "#{@text}"
			else
				fp.print "\tSentence id=#{@id}(#{article.id}) ATT:qs#{@isQuestion ?1:0} pol=#{@polarity} "
				(0...@evalPols.size).each{|i|
					fp.print "Eval[#{i}]=#{@evalEnts[i].to_s}(#{@evalSid}-#{@evalCids[i]},#{@evalPols[i]},#{@evalEnts[i].iterNo}) "
				}
				fp.puts "text=#{@text}"
				@chunks.each{|chunk|
					chunk.show(false,fp)
				}
			end
		end

	end
end

