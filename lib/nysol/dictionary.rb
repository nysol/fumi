#!/usr/bin/env ruby
# encoding: utf-8

# http://en.wikipedia.org/wiki/Japanese_grammar
# pPhrase: particle phrase : 格助詞句
# dPhrase: declined phrase : 用言句
# sentiment expression(SE) : 評価表現

#$KCODE = "u"
#require "jcode"
require "kconv"
require "rubygems"
require "nysol/mcmd"
require "nysol/phrase"

module TM
	class ProbDist
		def initialize(ub=200)
			@ub=ub
			@pascal=Array.new(ub+1,0)
			(0..ub).each{|i|
				@pascal[i]=Array.new(ub+1,0)
			}

			@pascal[0][0]=1
			(1..ub).each{|i|
				@pascal[i][0]=1
				@pascal[i][1]=i
				(2..i).each{|j|
					@pascal[i][j] = @pascal[i-1][j-1] + @pascal[i-1][j]
				}
			}
		end

		def combi(n,x)
			return @pascal[n][x]
		end

		# 正規分布の分布関数
		def normDist(x, mean, sd)
			return 1.0 - (1 + Math::erf((x - mean) / (sd * Math::sqrt(2)))) * 0.5
		end

  	def prob(x, n, p)
    	q = 1 - p
			accum=0.0
			if n>@ub then
				accum=normDist(x.to_f-0.5, n.to_f*p, Math::sqrt(n.to_f*p*q))
			else
				(x..n).each{|i|
					accum += combi(n,i) * (p ** i) * (q ** (n - i))
				}
			end
    	return accum
  	end   
	end

	########################################################
	# 単純エントリクラス
	########################################################
	class SimpleEntry
		attr_reader   :scFlag   # 0:SimpleEntry, 1:ComplexEntry
		attr_reader   :dPhrase  # 用言句
		attr_accessor :polarity # 極性
		attr_accessor :iterNo   # 辞書登録時のiterNo

		def initialize(dPhrase, polarity, iterNo=-1)
			@scFlag   = 0
			@dPhrase  = dPhrase
			@polarity = polarity
			@iterNo   = iterNo
#puts "se_reg=#{iterNo}"

		end

		# ====================================================
		# entryを文字列化する(ex. "回復する")
		# ====================================================
		def to_s
			return @dPhrase.to_s
		end

		def show(fp=STDERR)
			fp.print "SE:"
			@dPhrase.show(fp)
			fp.print "(pol=#{polarity})"
		end
	end

	########################################################
	# 複合エントリクラス
	########################################################
	class ComplexEntry
		attr_reader   :scFlag   # 0:SimpleEntry, 1:ComplexEntry
		attr_reader   :dPhrase  # 用言句
		attr_reader   :pPhrase  # 各助詞句
		attr_accessor :polarity # 極性(数値:-1 or 1)
		attr_accessor :iterNo   # 辞書登録時のiterNo

		def initialize(dPhrase, pPhrase, polarity, iterNo=-1)
			@scFlag   = 1
			@dPhrase  = dPhrase
			@pPhrase  = pPhrase
			@polarity = polarity
			@iterNo   = iterNo
		end

		# ====================================================
		# entryを文字列化する(ex. "景気が回復する")
		# ====================================================
		def to_s
			return @dPhrase.to_s + @pPhrase.to_s
		end

		def show(fp=STDERR)
			fp.print "CE:"
			@dPhrase.show(fp)
			@pPhrase.show(fp)
			fp.print "(#{polarity})"
		end
	end

	class SimpleEntryCand
		attr_reader :sEntry
		attr_accessor :posCount
		attr_accessor :negCount
		attr_accessor :ttlCount

		attr_accessor :suppFlg  # エントリの出現が一定以上
		attr_accessor :polarity
		attr_accessor :confFlg  # エントリの出現中の極性出現が一定以上
		attr_accessor :conf  # エントリの出現中の極性出現が一定以上

		def initialize(entry,pol)
#entry.show
#puts "pol=#{pol}"
			@sEntry=entry
#puts "sec_new=#{entry.iterNo}"
			@posCount=0
			@negCount=0
			@ttlCount=0
			@posCount=1 if pol == +1
			@negCount=1 if pol == -1
			@suppFlg =false
			@polarity=0
			@confFlg =false
		end

		def countUp(pol)
			@posCount+=1 if pol== +1
			@negCount+=1 if pol== -1
		end

		def prob(pol)
			if    pol== 1 then
				return posCount.to_f/ttlCount.to_f
			elsif pol==-1 then
				return negCount.to_f/ttlCount.to_f
			end
			return -1
		end

		def show(fp=STDERR)
			#return if not @suppFlg
			@sEntry.show(fp)
			fp.puts " (pc=#{@posCount},nc=#{@negCount},oc=#{@ttlCount-@posCount-@negCount},tc=#{@ttlCount}) (sup=#{@suppFlg} pol=#{@polarity} con=#{@confFlg}[#{@conf}])"
		end
	end

	class ComplexEntryCand
		attr_reader :cEntry
		attr_accessor :posCount
		attr_accessor :negCount
		attr_accessor :ttlCount

		attr_accessor :polarity # 
		attr_accessor :suppFlg  # エントリの出現が一定以上
		attr_accessor :confFlg  # エントリの出現中の極性出現が一定以上
		attr_accessor :conf  # エントリの出現中の極性出現が一定以上

		def initialize(entry,pol)
			@cEntry=entry
			@posCount=0
			@negCount=0
			@ttlCount=0
			@posCount=1 if pol == +1
			@negCount=1 if pol == -1
			@suppFlg =false
			@polarity=0
			@confFlg =false
		end

		def countUp(pol)
			@posCount+=1 if pol== +1
			@negCount+=1 if pol== -1
		end

		def prob(pol)
			if    pol== 1 then
				return posCount/ttlCount
			elsif pol==-1 then
				return negCount/ttlCount
			end
			return -1
		end

		def show(fp=STDERR)
			#return if @posCount==0 and @negCount==0
			#return if not @suppFlg
			@cEntry.show(fp)
			fp.puts " (pc=#{@posCount},nc=#{@negCount},oc=#{@ttlCount-@posCount-@negCount},tc=#{@ttlCount}) (sup=#{@suppFlg} pol=#{@polarity} con=#{@confFlg}[#{@conf}])"
		end
	end

	class Candidate
		attr_reader :sCandidates
		attr_reader :cCandidates
		attr_reader :iterNo

		def initialize(iterNo)
			@sCandidates = Hash.new # 単純エントリ
			@cCandidates = Hash.new # 複合エントリ
			@iterNo = iterNo
		end

		# 候補表現としてentryを極性polにて追加する
		def add(entry,pol)
			key=entry.to_s
			# --- 単純エントリ
			if entry.scFlag==0 then
				if @sCandidates.has_key?(key)
					@sCandidates[key].countUp(pol)
				else
					@sCandidates[key] = SimpleEntryCand.new(entry,pol)
				end

			# --- 複合エントリ
			else
				if @cCandidates.has_key?(key)
					@cCandidates[key].countUp(pol)
				else
					@cCandidates[key] = ComplexEntryCand.new(entry,pol)
				end
			end
		end

		# Candidateを統合する(Multi process対応にて利用)
		def addCand(cand)
			# 単純エントリ
			cand.sCandidates.each{|key,sCand|
				key=sCand.sEntry.to_s
				if not @sCandidates.has_key?(key)
					@sCandidates[key] = SimpleEntryCand.new(sCand.sEntry,0)
				end
#puts "sCand.count=(#{sCand.posCount},#{sCand.negCount})"
				@sCandidates[key].posCount += sCand.posCount
				@sCandidates[key].negCount += sCand.negCount
			}
			# 複合エントリ
			cand.cCandidates.each{|key,cCand|
				key=cCand.cEntry.to_s
				if not @cCandidates.has_key?(key)
					@cCandidates[key] = ComplexEntryCand.new(cCand.cEntry,0)
				end
				@cCandidates[key].posCount += cCand.posCount
				@cCandidates[key].negCount += cCand.negCount
			}
		end

		# エントリ文字列をキーとした総件数表をttlCountにセットする
		def setTotalCount(tbl)
			# 単純エントリ
			@sCandidates.each{|key,sCand|
				count=tbl[key]
				sCand.ttlCount = count
			}
			# 複合エントリ
			@cCandidates.each{|key,cCand|
				count=tbl[key]
				cCand.ttlCount = count
			}
				
		end

		# supportに満たないエントリを削除する
		def evalSupp(sSupp, cSupp)
			@sCandidates.each{|key,cand|
				if cand.ttlCount>=sSupp then
					cand.suppFlg=true
				else
					cand.suppFlg=false
				end
			}
			@cCandidates.each{|key,cand|
				if cand.ttlCount>=cSupp then
					cand.suppFlg=true
				else
					cand.suppFlg=false
				end
			}
		end

		# 一定割合(th)以上の極性を求める
		# posCount/(posCount+negCount)がth以上であれば+1
		# negCount/(posCount+negCount)がth以上であれば-1
		# その他は0
		def evalPol(th)
			@sCandidates.each{|key,cand|
				if    cand.posCount.to_f/(cand.posCount+cand.negCount).to_f >= th then
					cand.polarity=+1
				elsif cand.negCount.to_f/(cand.posCount+cand.negCount).to_f >= th then
					cand.polarity=-1
				else
					cand.polarity= 0
				end
			}
			@cCandidates.each{|key,cand|
				if    cand.posCount.to_f/(cand.posCount+cand.negCount).to_f >= th then
					cand.polarity=+1
				elsif cand.negCount.to_f/(cand.posCount+cand.negCount).to_f >= th then
					cand.polarity=-1
				else
					cand.polarity= 0
				end
			}
		end

		# posErrProb,negErrPorbをそれぞれの極性における誤用率と仮定し、
		# 各エントリの極性出現数が有意であればconfFlgをtrueとする。
		def evalConf(errProb, posSigLevel=0.05,negSigLevel=0.05)
			probDist=ProbDist.new
			@sCandidates.each{|key,cand|
				# 肯定極性
				if    cand.polarity == 1 then
					# 二項分布B(ttlCount,posErrPorb)においてcand.posCount以上の確率を求める
					cand.conf=probDist.prob(cand.posCount, cand.ttlCount, errProb)
					if cand.conf < posSigLevel
						cand.confFlg=true
					else
						cand.confFlg=false
					end

				# 否定極性
				elsif cand.polarity==-1 then
					# 二項分布B(ttlCount,negErrPorb)においてcand.posCount以上の確率を求める
					cand.conf=probDist.prob(cand.negCount, cand.ttlCount, errProb)
					if cand.conf < negSigLevel
						cand.confFlg=true
					else
						cand.confFlg=false
					end
				else
					cand.confFlg=false
				end
			}

			@cCandidates.each{|key,cand|
				# 肯定極性
				if    cand.polarity == 1 then
					# 二項分布B(ttlCount,posErrPorb)においてcand.posCount以上の確率を求める
					cand.conf=probDist.prob(cand.posCount, cand.ttlCount, errProb)
					if cand.conf < posSigLevel
						cand.confFlg=true
					else
						cand.confFlg=false
					end

				# 否定極性
				elsif cand.polarity==-1 then
					# 二項分布B(ttlCount,negErrPorb)においてcand.posCount以上の確率を求める
					cand.conf=probDist.prob(cand.negCount, cand.ttlCount, errProb)
					if cand.conf < negSigLevel
						cand.confFlg=true
					else
						cand.confFlg=false
					end
				else
					cand.confFlg=false
				end
			}
		end

		# 既に極性が判定されているエントリの誤用率を、その極性における推定誤用率として用いる
		def estProb
			posErrCount=0
			posTtlCount=0
			negErrCount=0
			negTtlCount=0
			@sCandidates.each{|key,cand|
				if    cand.sEntry.polarity== 1 then
					posErrCount+=cand.negCount
					posTtlCount+=cand.ttlCount
				elsif cand.sEntry.polarity==-1 then
					negErrCount+=cand.posCount
					negTtlCount+=cand.ttlCount
				end
			}

			posProb=negProb=0.0
			if posTtlCount>0 then
				posProb=posErrCount.to_f / posTtlCount.to_f
			end
			if negTtlCount>0 then
				negProb=negErrCount.to_f / negTtlCount.to_f
			end
			return posProb,negProb
		end

		def writeDic(dicName, chkFlg=true)
			count=0
		  File::open(dicName, "w"){|wfp|
				wfp.puts "用言句,格助詞句,格助詞,極性,iterNo,pos件数,neg件数,全件数"
				sOutput=Hash.new # 同じcEntryを出力しない為に出力されたsEntryを登録しておくHash
				@sCandidates.each{|key,cand|
					iterNo=cand.sEntry.iterNo
#if cand.sEntry.iterNo < 0 then
#print "begin: "; cand.sEntry.dPhrase.writePhrase(STDOUT) ; puts "(#{iterNo})"
#end
					if chkFlg then
						if iterNo < 0 then  # 辞書に登録されていなかったentry(辞書に登録されているentryは無条件で出力)
							next if cand.ttlCount > 5000
							#next if (cand.posCount+cand.negCount).to_f/cand.ttlCount.to_f > 0.5
							next if (not cand.suppFlg or cand.polarity==0 or not cand.confFlg) and cand.sEntry.polarity==0
						end
					end
					cand.sEntry.dPhrase.writePhrase(wfp) ; wfp.print ",,,"
					if cand.sEntry.polarity==0 then
						wfp.print cand.polarity            ; wfp.print ","
					else
						wfp.print cand.sEntry.polarity     ; wfp.print ","
					end
					#iterNo=cand.sEntry.iterNo
#cand.sEntry.dPhrase.writePhrase(STDOUT)
#puts ": it0=#{iterNo}, #{@iterNo}"
					iterNo=@iterNo if iterNo==-1
#puts "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx #{@iterNo}, #{iterNo} "
#puts "it1=#{iterNo}, #{@iterNo}"
					wfp.print iterNo                     ; wfp.print ","
					wfp.print cand.posCount              ; wfp.print ","
					wfp.print cand.negCount              ; wfp.print ","
					wfp.print cand.ttlCount              ; wfp.print "\n"
					count+=1

					sOutput[cand.sEntry.dPhrase.to_s]=1
				}
				@cCandidates.each{|key,cand|
					iterNo=cand.cEntry.iterNo
					if chkFlg then
						if iterNo < 0 then  # 辞書に登録されていなかったentry(辞書に登録されているentryは無条件で出力)
							next if cand.ttlCount > 5000
							#next if (cand.posCount+cand.negCount).to_f/cand.ttlCount.to_f > 0.5
							next if (not cand.suppFlg or cand.polarity==0 or not cand.confFlg) and cand.cEntry.polarity==0
							next if sOutput[cand.cEntry.dPhrase.to_s]!=nil # 用言句がsEntryにあれば出力しない
						end
					end
					cand.cEntry.dPhrase.writePhrase(wfp)   ; wfp.print ","
					cand.cEntry.pPhrase.writeWord(wfp)     ; wfp.print ","
					cand.cEntry.pPhrase.writeParticle(wfp) ; wfp.print ","
					if cand.cEntry.polarity==0 then
						wfp.print cand.polarity              ; wfp.print ","
					else
						wfp.print cand.cEntry.polarity       ; wfp.print ","
					end
					iterNo=cand.cEntry.iterNo
					iterNo=@iterNo if iterNo==-1
					wfp.print iterNo                       ; wfp.print ","
					wfp.print cand.posCount                ; wfp.print ","
					wfp.print cand.negCount                ; wfp.print ","
					wfp.print cand.ttlCount                ; wfp.print "\n"
					count+=1
				}
			}
			return count
		end

		def show(sort=0,fp=STDERR)
			@sCandidates.values.sort{|a,b|
				if sort==0 then
					a.ttlCount <=> b.ttlCount
				elsif sort==1 then
					(a.posCount <=> b.posCount)*(-2) + (a.ttlCount <=> b.ttlCount)*(-1)
				else
					(a.negCount <=> b.negCount)*(-2) + (a.ttlCount <=> b.ttlCount)*(-1)
				end
			}.each{|cand|
				cand.show(fp)
			}
			@cCandidates.values.sort{|a,b|
				if sort==0 then
					a.ttlCount <=> b.ttlCount
				elsif sort==1 then
					(a.posCount <=> b.posCount)*(-2) + (a.ttlCount <=> b.ttlCount)*(-1)
				else
					(a.negCount <=> b.negCount)*(-2) + (a.ttlCount <=> b.ttlCount)*(-1)
				end
			}.each{|cand|
				cand.show(fp)
			}
		end
	end

	########################################################
	# 辞書クラス
	# 複数の単純エントリ、複合エントリから構成される
	########################################################
	class Dictionary
		attr_reader :sEntries
		attr_reader :cEntries

		def initialize
			@sEntries = Hash.new # 単純エントリ
			@cEntries = Hash.new # 複合エントリ
		end

		# entryを辞書から検索し、辞書上のentryを返す。
		# なければnilを返す。
		def find(entry)
			result=nil
			if entry != nil then
#if @sEntries[entry.to_s]!=nil then
#puts "sss=#{entry.to_s}, no=#{@sEntries[entry.to_s].iterNo}"
#end
				if entry.scFlag==0 then
					result=@sEntries[entry.to_s]
				else
					result=@cEntries[entry.to_s]
				end
			end
			return result
		end

		# chunk上の全entryを辞書から検索し、該当する辞書上の全entryを返す。
		def findAll(chunk)
			result=[]
			# 単純エントリ辞書検索
			if dsEntry=find(chunk.sEntry) then 
				result << dsEntry

				# 複合エントリ辞書検索
				chunk.cEntries.each{|cEntry|
					if dcEntry=find(cEntry) then
						result << dsEntry
					end
				}
			end
			return result
		end

		# 指定した辞書ファイルから評価表現を読み込む
		# 0:用言句,1:格助詞句,2:格助詞,3:極性,4:iterNo
		def load(iFile)
			count=0
			Mcsv.new("i=" + iFile).each(true) {|nam,val|
				if not /\A#/=~ val[0] then # '#'から始まればコメントと考える(デバッグ目的で利用)
					#                     dPhrase,pPhrase,polarity
					dPhrase  = DeclinedPhrase.new(val[0])
					polarity = val[3].to_i
					iterNo   = val[4].to_i
					if val[1]==nil then
						entry = SimpleEntry.new(dPhrase, polarity, iterNo)
						@sEntries[entry.to_s] = entry
						count+=1
					else
						pPhrase = ParticlePhrase.new(val[1],val[2])
						entry = ComplexEntry.new(dPhrase, pPhrase, polarity, iterNo)
						@cEntries[entry.to_s] = entry
						count+=1
					end
				end
			}
			return count
		end

		def show(fp=STDERR)
			@sEntries.each{|key,entry|
				entry.show(fp)
				fp.puts ""
			}
			@cEntries.each{|key,entry|
				entry.show(fp)
				fp.puts ""
			}
		end
	end

	def addClique(fp)
		;
	end
end
