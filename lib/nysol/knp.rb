#!/usr/bin/env ruby
# encoding: utf-8

require 'fileutils'
require "rexml/document"
require 'kconv'
require 'rubygems'
require 'nysol/mcmd'
#$KCODE='u'

##########################
module TM

#
# 二つの中核メソッド
# txt2knp : 1つの文章をKNPでparsingしてknpフォーマットデータを得る。
# knp2xml : knpフォーマットデータを独自のsentence xmlフォーマットに変換する。
#
# その他の便利なインターフェース
# parsing(articles) : 文字列配列としてのarticlesをparsingしてarticle xmlを返す。
# parsing(path)     : path内の全記事ファイルをparsingしてarticle xml配列を返す。
#
class KNP
	attr_accessor :mpCount   # 並列処理数
	attr_accessor :poolSize  # 一回の並列処理で処理する文章数

	# 以下、knp実行時の制約条件(制約を破ると、その文章のparsingは強制終了してエラー処理)
	attr_accessor :maxLen    # 一文章最大長
	attr_accessor :maxSec    # knp処理時間最大値
	attr_accessor :sizeLimit # knpメモリ使用量最大値

	private
	def initialize(mpCount=5)
		@pid=$$
		@mpCount  =mpCount
		@poolSize =1000
		@maxLen   =512
		@maxSec   =30
		@sizeLimit=2000000
	end

	# --------------------------------------------------------------------------------------------------
	# ダブルクォーツ内のspaceをtabに変換する
	# --------------------------------------------------------------------------------------------------
	def spc2tab(line)
		while line.index('"')
			line=~/(^.*?)"(.*?)"(.*$)/
			#pre=$1.dup
			#body=$2.dup
			#post=$3.dup
			#line="#{pre}#DQ##{body.gsub(" ","#tab#")}#DQ##{post}"
			line="#{$1}#DQ##{$2.gsub(" ","#tab#")}#DQ##{$3}"
		end
		return line
	end

	# --------------------------------------------------------------------------------------------------
	# KNP parsingで利用するワークDirを削除し新たに空のdirを作成する。
	# --------------------------------------------------------------------------------------------------
	def cleanWorkDirs(xxtxt,xxknp)
		FileUtils.rm_r(xxknp) if File.exist?(xxknp)
		FileUtils.mkdir_p(xxknp)
		FileUtils.rm_r(xxtxt) if File.exist?(xxtxt)
		FileUtils.mkdir_p(xxtxt)
	end

	# --------------------------------------------------------------------------------------------------
	# フィアルiFileを、oPathに文章単位のファイルとして保存する
	# 保存した文章数を返す。文章がなかった場合は0を返す。
	#   文章番号をファイル名とする。0はタイトル行の文章を意味する。
	# --------------------------------------------------------------------------------------------------
	def sepSentence(iFile,oPath)

		aid=File.basename(iFile) #.sub(/\..*?$/,"")

		article=nil
		File.open(iFile,"r"){|fpr|
			article=fpr.read
		}
		sentences=[]
		article.split("\n").each{|line|
			sent=line.chomp.strip.gsub(" ","")
			next if sent==nil or sent==""
			sentences << sent
		}

		# クリーニングの結果、文章がなくなれば何もせずreturn。
		# 文章dirも作成しない。
		return 0 if sentences.size==0

		# 出力
		FileUtils.mkdir_p("#{oPath}/#{aid}")
		sid=0
		sentences.each{|sentence|
			oFile="#{oPath}/#{aid}/#{sid}"
			File.open(oFile,"w"){|fpw|
				fpw.puts(sentence)
			}
			sid+=1
		}

		return sentences.size
	end


	# ===================================================================================================
	# knpの出力結果をXMLに変換する
	# KNPが出力するフォーマットは以下の通り
	# * 1D <文頭><サ変><体言><係:未格><隣係絶対><用言一部><裸名詞><区切:0-0><RID:1464><格要素><連用要素><正規化代表表記:景気/けいき+後退/こうたい><主辞代表表記:後退/こうたい>
	# + 1D <文節内><係:文節内><文頭><体言><名詞項候補><先行詞候補><正規化代表表記:景気/けいき>
	# 景気 けいき 景気 名詞 6 普通名詞 1 * 0 * 0 "代表表記:景気/けいき カテゴリ:抽象物 ドメイン:ビジネス;政治" <代表表記:景気/けいき><カテゴリ:抽象物><ドメイン:ビジネス;政治><正規化代表表記:景気/けいき><文頭><漢字><かな漢字><名詞相当語><自立><内容語><タグ単位始><文節始>
	# + 2D <体言><係:未格><隣係絶対><用言一部><裸名詞><区切:0-0><RID:1464><格要素><連用要素><サ変><名詞項候補><先行詞候補><非用言格解析:動><照応ヒント:係><態:未定><正規化代表表記:後退/こうたい><解析格:ガ>
	# 後退 こうたい 後退 名詞 6 サ変名詞 2 * 0 * 0 "代表表記:後退/こうたい カテゴリ:抽象物 反義:名詞-サ変名詞:前進/ぜんしん" <代表表記:後退/こうたい><カテゴリ:抽象物><反義:名詞-サ変名詞:前進/ぜんしん><正規化代表表記:後退/こうたい><漢字><かな漢字><名詞相当語><サ変><自立><複合←><内容>語><タグ単位始><文節主辞>
	# * 5D <連体修飾><用言:動><係:連格><レベル:B><区切:0-5><ID:（動詞連体）><RID:708><連体並列条件><連体節><正規化代表表記:崩れる/くずれる><主辞代表表記:崩れる/くずれる>
	# + 8D <連体修飾><用言:動><係:連格><レベル:B><区切:0-5><ID:（動詞連体）><RID:708><連体並列条件><連体節><正規化代表表記:崩れる/くずれる><用言代表表記:崩れる/くずれる><格要素-ガ:後退><格要素-ヲ:NIL><格要素-ニ:NIL><格要素-ト:NIL><格要素-デ:NIL><格要素-カラ:NIL><格要素-ヨリ:NIL><格>
	# 要素-マデ:NIL><格要素-ヘ:NIL><格要素-時間:前年><格要素-ノ:NIL><格要素-修飾:NIL><格要素-外の関係:NIL><動態述語><時制-未来><格関係1:ガ:後退><格関係8:時間:前年><格解析結果:崩れる/くずれる:動1:ガ/N/後退/1/0/1;ヲ/U/-/-/-/-;ニ/U/-/-/-/-;ト/U/-/-/-/-;デ/U/-/-/-/-;カラ/U/-/-/-/-;ヨリ/U/-/-/-/-;マデ/U/-/-/-/-;ヘ/U/-/-/-/-;時間/N/前年/8/0/1;ノ/U/-/-/-/-;修飾/U/-/-/-/-;外の関係/U/-/-/-/-><正規化格解析結果-0:崩す/くずす:動1:ヲ/N/後退/1/0/1;時間/N/前年/8/0/1>
	# 崩れる くずれる 崩れる 動詞 2 * 0 母音動詞 1 基本形 2 "代表表記:崩れる/くずれる 自他動詞:他:崩す/くずす" <代表表記:崩れる/くずれる><自他動詞:他:崩す/くずす><正規化代表表記:崩れる/くずれる><かな漢字><活用語><自立><内容語><タグ単位始><文節始><文節主辞>
	# * 5D <サ変><助詞><連体修飾><体言><係:ノ格><区切:0-4><RID:1072><正規化代表表記:消費/しょうひ><主辞代表表記:消費/しょうひ>
	# + 8D <助詞><連体修飾><体言><係:ノ格><区切:0-4><RID:1072><サ変><名詞項候補><先行詞候補><非用言格解析:動><照応ヒント:係><態:未定><係チ:非用言格解析||用言&&文節内:Ｔ解析格-ヲ><正規化代表表記:消費/しょうひ>
	# 消費 しょうひ 消費 名詞 6 サ変名詞 2 * 0 * 0 "代表表記:消費/しょうひ カテゴリ:抽象物 ドメイン:家庭・暮らし;ビジネス 反義:名詞-サ変名詞:生産/せいさん" <代表表記:消費/しょうひ><カテゴリ:抽象物><ドメイン:家庭・暮らし;ビジネス><反義:名詞-サ変名詞:生産/せいさん><正規化代表表記:消費
	# /しょうひ><漢字><かな漢字><名詞相当語><サ変><自立><内容語><タグ単位始><文節始><文節主辞>
	# の の の 助詞 9 接続助詞 3 * 0 * 0 NIL <かな漢字><ひらがな><付属>
	# * 4D <時間><強時間><体言><係:隣><時数裸><区切:0-0><RID:1345><正規化代表表記:常識/じょうしき+戦後/せんご><主辞代表表記:戦後/せんご>
	# + 5D <文節内><係:文節内><体言><名詞項候補><先行詞候補><正規化代表表記:常識/じょうしき>
	# 常識 じょうしき 常識 名詞 6 普通名詞 1 * 0 * 0 "代表表記:常識/じょうしき カテゴリ:抽象物" <代表表記:常識/じょうしき><カテゴリ:抽象物><正規化代表表記:常識/じょうしき><漢字><かな漢字><名詞相当語><自立><内容語><タグ単位始><文節始>
	# + 6D <文節内><係:文節内><体言><名詞項候補><先行詞候補>
	# ： ： ： 特殊 1 記号 5 * 0 * 0 NIL <記英数カ><英記号><記号><自立><複合←><内容語><タグ単位始>
	# + 7D <時間><強時間><体言><係:隣><時数裸><区切:0-0><RID:1345><名詞項候補><正規化代表表記:戦後/せんご>
	# 戦後 せんご 戦後 名詞 6 時相名詞 10 * 0 * 0 "代表表記:戦後/せんご カテゴリ:時間" <代表表記:戦後/せんご><カテゴリ:時間><正規化代表表記:戦後/せんご><漢字><かな漢字><名詞相当語><自立><複合←><内容語><タグ単位始><文節主辞>
	#
	# * 5D <カウンタ:度><回数><数量><時数ノ><助詞><連体修飾><体言><準用言><受:隣のみ><修飾><係:ノ格><区切:0-4><RID:1072><正規化代表表記:２/に+度/ど><主辞代表表記:２/に+度/ど>
	# + 8D <カウンタ:度><回数><数量><時数ノ><助詞><連体修飾><体言><準用言><受:隣のみ><修飾><係:ノ格><区切:0-4><RID:1072><省略解析なし><正規化代表表記:２/に+度/ど>
	# ２ に ２ 名詞 6 数詞 7 * 0 * 0 "疑似代表表記 代表表記:２/に" <疑似代表表記><代表表記:２/に><正規化代表表記:２/に><記英数カ><数字><名詞相当語><自立><内容語><タグ単位始><文節始>
	# 度 ど 度 接尾辞 14 名詞性名詞助数辞 3 * 0 * 0 "代表表記:度/ど 準内容語 カテゴリ:数量" <代表表記:度/ど><準内容語><カテゴリ:数量><正規化代表表記:度/ど><カウンタ><漢字><かな漢字><付属><文節主辞>
	# 目 め 目 接尾辞 14 名詞性名詞接尾辞 2 * 0 * 0 "代表表記:目/め" <代表表記:目/め><正規化代表表記:目/め><漢字><かな漢字><名詞相当語><付属>
	# の の の 助詞 9 接続助詞 3 * 0 * 0 NIL <かな漢字><ひらがな><付属>
	# * 6D <時間><強時間><体言><係:無格><区切:0-0><RID:1348><格要素><連用要素><正規化代表表記:前年/ぜんねん><主辞代表表記:前年/ぜんねん>
	# + 9D <時間><強時間><体言><係:無格><区切:0-0><RID:1348><格要素><連用要素><名詞項候補><正規化代表表記:前年/ぜんねん><解析連格:時間><解析格:時間>
	# 前年 ぜんねん 前年 名詞 6 時相名詞 10 * 0 * 0 "代表表記:前年/ぜんねん カテゴリ:時間" <代表表記:前年/ぜんねん><カテゴリ:時間><正規化代表表記:前年/ぜんねん><漢字><かな漢字><名詞相当語><自立><内容語><タグ単位始><文節始><文節主辞>
	# * -1D <文末><モ><句点><助詞><用言:動><レベル:C><区切:5-5><ID:（文末）><RID:1498><係:文末><提題受:30><主節><格要素><連用要素><モダリティ-命令><正規化代表表記:割る/わる><主辞代表表記:割る/わる>
	# + -1D <文末><モ><句点><助詞><用言:動><レベル:C><区切:5-5><ID:（文末）><RID:1498><係:文末><提題受:30><主節><格要素><連用要素><モダリティ-命令><正規化代表表記:割る/わる><用言代表表記:割る/わる><格要素-ガ:＃二人称><格要素-ヲ:NIL><格要素-ニ:NIL><格要素-ト:NIL><格要素-デ:NIL><格要>
	# 素-カラ:NIL><格要素-時間:前年><格要素-修飾:NIL><格要素-ノ:NIL><格要素-外の関係:NIL><格フレーム-ガ-主体準><格フレーム-ガ-主体ｏｒ主体準><動態述語><格要素-＃:＃欲求主体><主題格:一人称優位><格関係8:時間:前年><格解析結果:割る/わる:動7:ガ/U/-/-/-/-;ヲ/U/-/-/-/-;ニ/U/-/-/-/-;ト/U/-/-/-/-;デ/U/-/-/-/-;カラ/U/-/-/-/-;時間/C/前年/8/0/1;修飾/U/-/-/-/-;ノ/U/-/-/-/-;外の関係/U/-/-/-/->
	# 割れ われ 割る 動詞 2 * 0 子音動詞ラ行 10 命令形 6 "代表表記:割る/わる 自他動詞:自:割れる/われる 名詞派生:割/わり" <代表表記:割る/わる><自他動詞:自:割れる/われる><名詞派生:割/わり><正規化代表表記:割る/わる><かな漢字><活用語><自立><内容語><タグ単位始><文節始><文節主辞>
	# も も も 助詞 9 接続助詞 3 * 0 * 0 NIL <表現文末><かな漢字><ひらがな><付属>
	# 。 。 。 特殊 1 句点 1 * 0 * 0 NIL <文末><英記号><記号><付属>
	# EOS

	# 以下のようなXMLを構築する
	# <?xml version='1.0' encoding='UTF-8'?>
	# <article id='00000001' date='20081130' page='1'>
	# <?xml version='1.0' encoding='UTF-8'?>
	#	<sentence text='景気後退崩れる消費の常識：戦後２度目の前年割れも。' id='0'>
	#    <chunk phrase='景気後退' caseType='ガ格' id='0' phraseType='格助詞句' link='1'>
	#      <token orgWord='景気' word='景気' class1='名詞' class2='普通名詞' class3='' id='0' class4=''/>
	#      <token orgWord='後退' word='後退' class1='名詞' class2='サ変名詞' class3='' id='1' class4=''/>
	#    </chunk>
	#    <chunk phrase='崩れる' id='1' phraseType='用言句' link='5'>
	#      <token orgWord='崩れる' word='崩れる' class1='動詞' class2='' class3='母音動詞' id='2' class4='基本形'/>
	#    </chunk>
	#    <chunk phrase='消費' id='2' link='5'>
	#      <token orgWord='消費' word='消費' class1='名詞' class2='サ変名詞' class3='' id='3' class4=''/>
	#      <token orgWord='の' word='の' class1='助詞' class2='接続助詞' class3='' id='4' class4=''/>
	#    </chunk>
	#    <chunk phrase='常識：戦後' id='3' link='4'>
	#      <token orgWord='常識' word='常識' class1='名詞' class2='普通名詞' class3='' id='5' class4=''/>
	#      <token orgWord='：' word='：' class1='特殊' class2='記号' class3='' id='6' class4=''/>
	#      <token orgWord='戦後' word='戦後' class1='名詞' class2='時相名詞' class3='' id='7' class4=''/>
	#    </chunk>
	#    <chunk phrase='２度目' id='4' link='5'>
	#      <token orgWord='２' word='２' class1='名詞' class2='数詞' class3='' id='8' class4=''/>
	#      <token orgWord='度' word='度' class1='接尾辞' class2='名詞性名詞助数辞' class3='' id='9' class4=''/>
	#      <token orgWord='目' word='目' class1='接尾辞' class2='名詞性名詞接尾辞' class3='' id='10' class4=''/>
	#      <token orgWord='の' word='の' class1='助詞' class2='接続助詞' class3='' id='11' class4=''/>
	#    </chunk>
	#    <chunk phrase='前年' caseType='時間格' id='5' phraseType='格助詞句' link='6'>
	#      <token orgWord='前年' word='前年' class1='名詞' class2='時相名詞' class3='' id='12' class4=''/>
	#    </chunk>
	#    <chunk phrase='割る' id='6' phraseType='用言句' link='-1'>
	#      <token orgWord='割れ' word='割る' class1='動詞' class2='' class3='子音動詞ラ行' id='13' class4='命令形'/>
	#      <token orgWord='も' word='も' class1='助詞' class2='接続助詞' class3='' id='14' class4=''/>
	#      <token orgWord='。' word='。' class1='特殊' class2='句点' class3='' id='15' class4=''/>
	#    </chunk>
	#  </sentence>
	# ===================================================================================================
	def knp2xml(knpDoc,sid)
		cNo=0
		pNo=0
		tNo=0
		text=""
		phraseType=""
		phraseTok=""  # tokから生成するphrase(現在使っていない)
		phrase=""
		vague=false
		ableVerbFlag=false
		rawPhrase=""
		chunk=nil
		youEnd=false # 用言のphrase出力が終了したフラグ
		doc=REXML::Document.new
		sentence = doc.add_element("sentence", {"id"=>sid}) 

		knpDoc.split("\n").each {|line|
			line.strip!
			line=spc2tab(line)
			flds=line.split(" ")

			# ---------------------------------------------------------------
			# header
			if flds[0]=="#" then
				;

			# ---------------------------------------------------------------
			# 終端
			elsif flds[0]=="EOS" then
				next if chunk==nil # いきなりEOS(KNPがエラー終了したとき)
				sentence.add_attribute("text",text)
				chunk.add_attribute("phraseTok",phraseTok)
				chunk.add_attribute("rawPhrase",rawPhrase)
				if vague or ableVerbFlag then
					chunk.add_attribute("phrase",phraseTok) 
				else
					chunk.add_attribute("phrase",phrase) 
				end
				break

			# ---------------------------------------------------------------
			# 文節(chunk)
			# * 8D <用言:動><係:連用><レベル:B+><区切:3-5><ID:〜ので><RID:333><提題受:20><連用要素><連用節><正規化代表表記:困る/こまる><主辞代表表記:困る/こまる>
			elsif flds[0]=="*" then
				if chunk!=nil
					if vague or ableVerbFlag then
						chunk.add_attribute("phrase",phraseTok) 
					else
						chunk.add_attribute("phrase",phrase) 
					end
				end
				#chunk.add_attribute("phrase",phrase) if chunk!=nil
				chunk.add_attribute("phraseTok",phraseTok) if chunk!=nil
				chunk.add_attribute("rawPhrase",rawPhrase) if chunk!=nil
				phraseType=""
				phraseTok=""
				phrase=""
				ableVerbFlag=false
				rawPhrase=""
				youEnd=false
				kakari=yougen=""
				inyou=wish=FALSE # 引用内文末,願望
				linkTo=nil
				#puts "文節"
				linkTo=flds[1].sub("D","").to_i
				items=flds[2].gsub("<","").split(">")
				if items!=nil then
					items.each{|item|
						if(item=~/^係:.*格/)
							kakari=item.sub("係:","").sub("格","")
						elsif(item=~/^用言:.*/)
							yougen=item.sub("用言:","")
						elsif(item=="引用内文末")
							inyou=TRUE
						elsif(item=~/^主辞代表表記:.+/) then
							phrase=item.split(":")[1].split("/")[0]
							vague=false
							if item.split(":")[1].split("/")[1]!=nil
								vague=true if item.split(":")[1].split("/")[1].index("?")
							end
						elsif(item=="〜たい" or item=="〜ほしい")
							wish=TRUE
						end
					}
				end

				# xml登録
				#sentence.add_attribute("text",text)
				chunk = sentence.add_element("chunk")
				chunk.add_attribute("id",cNo.to_s)
				chunk.add_attribute("link",linkTo.to_s)
				if yougen!="" then
					phraseType="用言句"
					chunk.add_attribute("phraseType","用言句")
				end
				chunk.add_attribute("end_of_quotation","true") if inyou
				chunk.add_attribute("wish","true") if wish
				#chunk.add_attribute("kakari",kakari) if kakari!=""
				#chunk.add_attribute("yougen",yougen) if yougen!=""
				cNo+=1

			# ---------------------------------------------------------------
			# 句(phrase)
			# + -1D <文末><モ><句点><助詞><用言:動><レベル:C><区切:5-5><ID:（文末）><RID:1498><係:文末><提題受:30><主節><格要素><連用要素><モダリティ-命令><正規化代表表記:割る/わる><用言代表表記:割る/わる><格要素-ガ:＃二人称><格要素-ヲ:NIL><格要素-ニ:NIL><格要素-ト:NIL><格要素-デ:NIL><格要>
			elsif flds[0]=="+" then
				#puts "句"
				#linkTo=flds[1].sub("D","").to_i
				items=flds[2].gsub("<","").split(">")
				items.each{|item|
					if(item=~/^解析格:.*/)
						kaiseki=item.sub("解析格:","")
						chunk.add_attribute("phraseType","格助詞句")
						chunk.add_attribute("caseType",kaiseki+"格")
					elsif(item=="節機能-条件")
						chunk.add_attribute("conditional","true")
					end
				}
				pNo+=1

			# ---------------------------------------------------------------
			# 形態素(token)
			else
				orgw=yomi=word=daiw=cls1=cls2=cls3=cls4=category=domain=ableVerb=nil
				tok = chunk.add_element("token")

				orgw=flds[0]
				yomi=flds[1]
				word=flds[2]
				cls1=flds[3] if flds[3]!="*"
				cls2=flds[5] if flds[5]!="*"
				cls3=flds[7] if flds[7]!="*"
				cls4=flds[9] if flds[9]!="*"
				text << orgw
				flds[12] ="" if flds[12]==nil
				items=flds[12].gsub("<","").split(">")
				items.each{|item|
					if(item=~/^カテゴリ:/) then
						category = item.split(":")[1]
					elsif(item=~/^ドメイン:/) then
						domain   = item.split(":")[1]
					# <代表表記:楽しめる/たのしめる><可能動詞:楽しむ/たのしむ>		
					elsif(item=~/^可能動詞:/) then
						ableVerb= item.split(":")[1].split("/")[0]
						ableVerbFlag=true
					elsif(item=~/^代表表記:/) then
						daiw = item.split(":")[1]
						daiw = daiw.split("/")[0] if daiw
					end
				}

				tok.add_attribute("id",tNo)
				tok.add_attribute("class1",cls1)
				tok.add_attribute("class2",cls2)
				tok.add_attribute("class3",cls3)
				tok.add_attribute("class4",cls4)
				tok.add_attribute("word",word)
				tok.add_attribute("orgWord",orgw)
				tok.add_attribute("daiWord",daiw)
				tok.add_attribute("category",category)
				tok.add_attribute("domain",domain)
				tNo+=1

				# phrase(格助詞句もしくは用言句)を構成する

				#格助詞句、用言句として含めない形態素 (、や「は記号として認識されない時がある)
				skip=(cls2=="読点" or cls2=="句点" or cls2=="括弧始" or cls2=="括弧終" or cls2=="空白" or cls2=="記号" or word=~/、/ or word=~/「/)

				rawPhrase+=orgw
				# ========== 用言句の場合
				if phraseType=="用言句"
					word=ableVerb if ableVerb!=nil # 可能動詞がセットされば場合は、それを使う(ex. 楽しめる->楽しむ)
					#youEnd=true if cls1=="特殊" or cls1=="助詞" or cls1=="助動詞" or (cls1=="接尾辞" and cls2!="名詞性名詞接尾辞") or (word=="する" and phraseTok!="") # これらの品詞が出てきたら、そこまでを用言句とする。

					# これらの品詞が出てきたら、そこまでを用言句とする。
					youEnd=true if cls1=="特殊" or cls1=="助詞" or cls1=="助動詞" or cls1=="接尾辞"

					# 用言句を構成
					phraseTok+=word if not (youEnd or skip)

					# 動詞が出てくればそこまでを用言とする。
					youEnd=true if cls1=="動詞"

				# ========== 用言句以外の場合
				else
					#phraseTok+=orgw if cls1!="特殊" and cls1!="助詞" and cls1!="助動詞"
					phraseTok+=orgw if not (skip or cls1=="助詞" or cls1=="助動詞")
				end

				#puts "形態素: #{orgw}, #{yomi}, #{word}, #{cls1}, #{cls2}, #{cls3}, #{cls4}, #{category}, #{domain}"
			end
		}

		return doc
	end

	# ハウス はうす ハウス 名詞 6 普通名詞 1 * 0 * 0 "代表表記:ハウス/はうす カテゴリ:場所-施設"
	# 、 、 、 特殊 1 読点 2 * 0 * 0 NIL
	# 機能 きのう 機能 名詞 6 サ変名詞 2 * 0 * 0 "代表表記:機能/きのう カテゴリ:抽象物"
	# 性 せい 性 接尾辞 14 名詞性名詞接尾辞 2 * 0 * 0 "代表表記:性/せい 準内容語 カテゴリ:抽象物"
	# 重視 じゅうし 重視 名詞 6 サ変名詞 2 * 0 * 0 "代表表記:重視/じゅうし カテゴリ:抽象物 反義:名詞-サ変名詞:軽視/けいし"
	# の の の 助詞 9 接続助詞 3 * 0 * 0 NIL
	# キャンデー きゃんでー キャンデー 名詞 6 普通名詞 1 * 0 * 0 "代表表記:キャンデー/きゃんでー カテゴリ:人工物-食べ物 ドメイン:料理・食事"
	# ３ さん ３ 名詞 6 数詞 7 * 0 * 0 NIL
	# 種 しゅ 種 名詞 6 普通名詞 1 * 0 * 0 "代表表記:種/しゅ 漢字読み:音 カテゴリ:抽象物"
	# @ 種 たね 種 名詞 6 普通名詞 1 * 0 * 0 "代表表記:種/たね 漢字読み:訓 カテゴリ:人工物-その他"
	# 。 。 。 特殊 1 句点 1 * 0 * 0 NIL
	# EOS
	def jum2csv(jumDoc,sid)
		csv=[]
		tNo=0
		jumDoc.split("\n").each {|line|
			line.strip!
			line=spc2tab(line)
			flds=line.split(" ")

			# ---------------------------------------------------------------
			# 終端
			if flds[0]=="EOS" then
				next if tNo==0 # いきなりEOS(JUMANがエラー終了したとき)
				break

			# ---------------------------------------------------------------
			# 文節(chunk)
			# * 8D <用言:動><係:連用><レベル:B+><区切:3-5><ID:〜ので><RID:333><提題受:20><連用要素><連用節><正規化代表表記:困る/こまる><主辞代表表記:困る/こまる>
			else
				orgw=yomi=word=cls1=cls2=cls3=cls4=nil

				orgw=flds[0]
				yomi=flds[1]
				word=flds[2]
				cls1=flds[3] if flds[3]!="*"
				cls2=flds[5] if flds[5]!="*"
				cls3=flds[7] if flds[7]!="*"
				cls4=flds[9] if flds[9]!="*"

				# "代表表記:林檎/りんご カテゴリ:植物;人工物-食べ物 ドメイン:料理・食事"
				anno=flds[11]
				anno=nil if anno=="NIL"
				dai=nil
				if anno then
					anno=anno.gsub("#tab#"," ").gsub("#DQ#","")
					ary=anno.split(" ")
					ary.each{|term|
						if term=~/代表表記/
							dai=term.split(":")[1]
							if dai
								dai=dai.split("/")[0] if dai
							else
								dai=nil
							end
						end
					}
				end

				csv << [tNo,word,orgw,dai,yomi,cls1,cls2,cls3,cls4,anno]
				#puts "形態素: #{word}, #{yomi}, #{orgw}, #{cls1}, #{cls2}, #{cls3}, #{cls4}, #{anno}"

				tNo+=1
			end
		}

		return csv
	end


	# ===================================================================================================
	# テキストをKNPでparsingする。テキストは一つの文章で構成されている事を前提とする。
	# 引数
	#   text   : テキスト(文字列)
	# 返り値
	#   status,knp結果文字列
	#   status:
	#     success     : parsing成功
	#     lengthError : 文字長制約を満たさなかったエラー
	#     timeError   : 最大処理時間を満たさなかったエラー
	#     MemOverError: メモリ使用量が規定値を超えたエラー
	#     unknownError: その他のエラー
	# ===================================================================================================
	def txt2knp(text,juman)
		pid=$$
		st=Time.new
		if text==nil
			return "nilError",nil,nil,nil
		end
		text=text.strip
		#length = text.length
		length = text.bytesize # ruby 1.8と1.9での動作を合わせるためbytesizeを使う

		# 長さ制約検査
		if text.size==0
			return "emptyError",nil,length,nil
		end

		if length>@maxLen then
			return "lengthError",nil,length,nil
		end

		begin
			temp=MCMD::Mtemp.new
			# textをファイルに落としKNPを実行する
			wfi=temp.file
			wfo=temp.file

			File.open(wfi,"w"){|fpw|
				fpw.puts text
			}

			# knp用子プロセスIDとタイマー用子プロセスID
			@cid=@tid=nil

			# USR1シグナルを子プロセスから受け取るということは閾値秒以上経過したということでparseエラー
  		Signal.trap("USR1"){
				#sentence.add_attribute("status","error: parsing time out")
				FileUtils.rm(wfi)
				FileUtils.rm(wfo)
				Process.kill("KILL",@tid)
				return "timeError",nil,length,@maxSec
			}
  		Signal.trap("USR2"){
				#sentence.add_attribute("status","error: parsing time out")
				FileUtils.rm(wfi)
				FileUtils.rm(wfo)
				Process.kill("KILL",@tid)
				return "MemOverError",nil,length,@maxSec
			}

			# 子プロセス(pid)にてknpを起動する。
			@cid=fork{
				if juman then
					exec("juman -e2 -b < #{wfi} >#{wfo}")
				else
					exec("juman -e2 -B < #{wfi} | knp -tab >#{wfo}")
				end
				exit!
			}

			# タイマープロセスを起動する。
			@tid=fork{
				process_chk_Temp=MCMD::Mtemp.new
				process_chk_Path=process_chk_Temp.file
				while true
					check_flg=false
					sleep 5 # 一定秒数sleepする
					rtn = system("ps -o pid,ppid,rss,comm,time >#{process_chk_Path}") 
					File.open(process_chk_Path,"r"){|fpr|
						while line=fpr.gets
							pid_c,ppid,rss,comm,time=line.strip.split(/\s+/)
							next if comm!="knp"
							next if ppid!="#{@cid}" 
							check_flg =true
							# 経過時間計測
							times=time.split(":")
							seconds=times[-2].to_i*60+times[-1].to_i
							# @sizeLimit(KB)を超えたら発動
							if rss.to_i>=@sizeLimit
								Process.kill("KILL",pid_c.to_i) 
								Process.kill("KILL",@cid) 
								Process.kill("USR2",pid) 
								break
							# timeLimit秒を超えたら発動
							elsif seconds>=@maxSec
								Process.kill("KILL",pid_c.to_i) 
								Process.kill("KILL",@cid) 
								Process.kill("USR1",pid) 
								break
							end
						end
						break unless check_flg
					}
				end
				exit!
			}

			# knpプロセスの終了を待つ(timerプロセスはdetach)
			Process.detach(@tid)
			Process.waitpid(@cid)

			# タイマーのプロセスを終了する
			begin
				Process.kill("KILL",@tid)
			rescue
			end

			# parse終了メッセージ
			#et=Time.new
			#lap=et-st
			#flg=""
			#flg="==============================================================" if lap>60
			#puts "KNP done: length=#{text.length} time=#{lap} #{flg}"

			# 結果をencoding変換＆workファイル削除
			doc=nil
			File.open(wfo,"r"){|fpr|
				doc=fpr.read
			}
			FileUtils.rm(wfi)
			FileUtils.rm(wfo)
			return "success",doc,length,Time.new-st
		rescue
			return "unknownError",nil,text.bytesize,Time.new-st
		end
	end

	# ===================================================================================================
	# 一行一文章一ファイルが格納されたiFilesの全ファイルをKNPでparsingして、その結果をoPathに書き出す。
	#   iFilesのファイル名の後ろは"#{aid}/#{sid}"でなければならない。ここで、sidは0以上の整数。
	# 返り値:
	#   parsingエラーとなった"#{エラーステータス},#{ファイル名}"の配列。
	# aCount: 現在poolに入っている文書番号の最大値
	# aTotal: 全文書数
	# ===================================================================================================
	def txt2knp_MP(iFiles, knpPath, aCount, aTotal, juman=false)
		totalCount=iFiles.size
		temp=MCMD::Mtemp.new
		errPath=temp.file

		FileUtils.rm_r(errPath) if File.exist?(errPath)
		FileUtils.mkdir_p(errPath)

		count=0 # 何個目のファイルを処理中か
		running=0 # 稼働中のプロセス数
		while true
			break if iFiles.size==0

			# 配列からファイルを１個取り出す。
			fName=iFiles.delete_at(0)
			running+=1
			count+=1
			sid=File.basename(fName)
			aid=File.basename(File.dirname(fName))
			#knpPath  ="./xxknp" #temp.new_name
			FileUtils.mkdir_p("#{knpPath}/#{aid}")
			knpFile="#{knpPath}/#{aid}/#{sid}"
			errFile="#{errPath}/#{aid}_#{sid}"
			msg="KNP"
			msg="JUMAN" if juman
			MCMD::msgLog "#{msg}: MP-#{@mpCount} aid=#{aid} sid=#{sid} (sentences:#{count}/#{totalCount}, articles:#{aCount}/#{aTotal})"
			pid=fork {
				text=nil
				File.open(fName,"r"){|fpr|
					text=fpr.read.chomp.strip
				}
				MCMD::warningLog "KNP WARRING: double quotation mark is contained in #{aid}_#{sid}." if(text=~/\"/)
				status,knpDoc=txt2knp(text, juman)

				# マルチプロセスなので、エラー時はステータスをファイル出力し親が集める。
				if status!="success"
					File.open(errFile,"w"){|fpe|
						fpe.puts "#{status},#{fName}"
					}
				else
					File.open(knpFile,"w"){|fpw|
						fpw.write(knpDoc)
					}
				end
				exit!
			}

			if running >=@mpCount then
				begin
					Process.wait
					running-=1
				rescue
					MCMD::errorLog "no process found"
					exit
				end
			end
		end
		Process.waitall

		# 各プロセスでスキップされたファイルを記録したファイル
		errList=[]
		Dir["#{errPath}/*"].each{|file|
		
			File.open(file,"r"){|fpr|
				while line=fpr.gets
					line=line.chomp
					errList << line
				end
			}
		}
		return errList
	end

	# ===================================================================================================
	# 記事単位のdir(iFiles)をarticle xmlに変換する。結果を"#{oPath}/#{aid}.xml"として書き出す。
	# iPathにあるファイル名は"#{aid}/#{sid}"でなければならない。ここで、sidは0以上の整数。
	# ===================================================================================================
	def jum2csv_MP(iFiles, oPath)
		totalCount=iFiles.size

		count=0 # 何個目のファイルを処理中か
		running=0 # 稼働中のプロセス数
		while true
			break if iFiles.size==0

			# 配列からファイルを１個取り出す。
			kDir=iFiles.delete_at(0)
			running+=1
			count+=1
			aid=File.basename(kDir)
			csvFile="#{oPath}/#{aid}"
			MCMD::msgLog "JUM2CSV #{count}/#{totalCount}"
			pid=fork {
				# 文章別にCSVに変換
				sids=[]
				Dir["#{kDir}/*"].each{|file|
					sids << File.basename(file).to_i
				}
				sids.sort!

				# 出力
				MCMD::Mcsvout::new("o=#{csvFile} f=aid,sid,tid,word,orgWord,daiWord,yomi,class1,class2,class3,class4,annotation"){|ocsv|
					sids.each{|sid|
						asid=[aid,sid] # 記事IDと文章ID
						csvs=nil # 文章を構成するtokenの属性配列の配列
						File.open("#{kDir}/#{sid}","r"){|fpr|
							jumDoc=fpr.read
							csvs = jum2csv(jumDoc,sid)
						}
						csvs.each{|csv|
							ocsv.write(asid+csv)
						}
					}
				}
				exit!
			}

			if running >=@mpCount then
				begin
					Process.wait
					running-=1
				rescue
					MCMD::errorLog "no process found"
					exit
				end
			end
		end

		Process.waitall
	end


	# ===================================================================================================
	# 記事単位のdir(iFiles)をarticle xmlに変換する。結果を"#{oPath}/#{aid}.xml"として書き出す。
	# iPathにあるファイル名は"#{aid}/#{sid}"でなければならない。ここで、sidは0以上の整数。
	# ===================================================================================================
	def knp2xml_MP(iFiles, oPath)
		totalCount=iFiles.size

		count=0 # 何個目のファイルを処理中か
		running=0 # 稼働中のプロセス数
		while true
			break if iFiles.size==0

			# 配列からファイルを１個取り出す。
			kDir=iFiles.delete_at(0)
			running+=1
			count+=1
			aid=File.basename(kDir)
			xmlFile="#{oPath}/#{aid}"
			MCMD::msgLog "KNP2XML #{count}/#{totalCount}"
			pid=fork {
				# 文章別にXMLに変換
				sids=[]
				Dir["#{kDir}/*"].each{|file|
					sids << File.basename(file).to_i
				}
				sids.sort!

				xmlSentences=[]
				sids.each{|sid|
					File.open("#{kDir}/#{sid}","r"){|fpr|
						knpDoc=fpr.read
						xmlSentences << knp2xml(knpDoc,sid)
					}
				}

				# 文章をまとめて記事として構成
				xmlDoc=REXML::Document.new
				xmlDoc << REXML::XMLDecl.new("1.0","UTF-8")        # xml宣言
				article=xmlDoc.add_element("article", {"id"=>aid}) # ルート要素
				xmlSentences.each{|sent|
					article.push sent.elements["sentence"]
				}
				File.open(xmlFile,"w"){|fpw|
					xmlDoc.write(fpw,2)
				}
				exit!
			}

			if running >=@mpCount then
				begin
					Process.wait
					running-=1
				rescue
					MCMD::errorLog "no process found"
					exit
				end
			end
		end

		Process.waitall
	end


	#小数点以下2桁に四捨五入
	def round2(f,base=1000)
		return (f*base).round.to_f/base
	end

	# ===================================================================================================
	# 記事ファイルが格納されたiPathの全ファイルをKNPでparsingする。
	# KNPの結果はkPathに、XMLに変換した物はxPathに書き出す。
	# iPathにあるファイル名は"#{aid}/#{sid}"でなければならない。ここで、sidは0以上の整数。
	# mpCount: マルチプロセス数
	#
	# 記事ファイルを文章別ファイルに分解し、その数がpoolSizeを超えればknpによるparsingを実行し、
	# その結果をXMLに変換する。このような操作を文章がなくなるまで続ける。
	# ===================================================================================================
	def parsing(iPath, xPath, kPath=nil, juman=false)
		tStart=Time.new

		sAccum    =0  # 処理した文章数の累積
		sAccumTemp=0  # １フェーズの文章数をカウントするための一時変数
				
		articles=Dir["#{iPath}/*"]
		aTotal=articles.size

		# 以下メンバー変数だと問題ないが、ローカル変数にするとtxt2knpのwaitpid(@cid)にてMtempオブジェクトのデストラクタが起動してしまう。
		@parsingTemp=MCMD::Mtemp.new
		xxtxt=@parsingTemp.file
		xxknp=@parsingTemp.file
		cleanWorkDirs(xxtxt,xxknp)

		errList=[]
		aCount=0   # 文書(article)カウンタ
		articles.each{|article|
			aCount+=1
			fileName=File.basename(article)

			isLast=false
			isLast=true if article==articles.last

			#p article
			# articleをxxtxtに文章別ファイルに展開する
			# #{xxtxt} 以下にaid__sid のファイル名で作成される。
			# 生成された文章数を得る。
			sCount=sepSentence(article,xxtxt)
			sAccum    +=sCount
			sAccumTemp+=sCount
			MCMD::msgLog "KNP: reading #{article}; # of sentences=#{sCount}(#{sAccumTemp})"

			# １フェーズあたりの最大文章数を超えたら並列処理に入る
			#puts "sAccum=#{sAccum}, poolSize=#{poolSize}, isLast=#{isLast}"
			if sAccumTemp > @poolSize or isLast then

				# xxtxt以下の全ファイルをマルチプロセスでparsingする。
				# #{knpPath}/knp 以下に#{aid}/#{sid}のファイル名でknpのparsing結果が作成される。
				files=Dir["#{xxtxt}/*/*"]
				err = txt2knp_MP(files,xxknp, aCount, aTotal, juman)
				errList.concat(err)

				# 結果出力
				files=Dir["#{xxknp}/*"]

				# 1. KNP(JUMAN)のparsing結果出力
				if kPath!=nil then
					files.each{|file|
						aid=File.basename(file) #.sub(/\..*?$/,"")
						#next if Dir["#{file}/*"].size==0
						system("echo #{file}/* | xargs -n 100 cat >#{kPath}/#{aid}")
					}
				end

				# 2. XMLに変換して出力
				if xPath!=nil then
					# knpファイルをxmlに変換する。
					# #{xPath} 以下にaid.xmlのファイル名で記事xmlが作成される。
					if juman then
						jum2csv_MP(files, xPath)
					else
						knp2xml_MP(files, xPath)
					end
				end

				# 作業ディレクトリ内の全ファイルを削除する。
				cleanWorkDirs(xxtxt,xxknp)
				sAccumTemp=0

				# 時間計測結果出力
				tTime   = Time.new - tStart                 # 総経過時間
				sAvg    = round2(tTime.to_f/sAccum.to_f) # 
				aAvg    = round2(tTime.to_f/aCount.to_f) # 

				MCMD::msgLog("Elapse: #{round2(tTime)}sec, # of sentences=#{sAccum}, # of articles=#{aCount}",false)
				MCMD::msgLog("  #{sAvg}sec/sentence, #{aAvg}sec/article",false)
				MCMD::msgLog("  mpCount=#{@mpCount}, poolSize=#{@poolSize}",false)
				MCMD::msgLog("  maxLen=#{@maxLen}Byte, maxSec=#{@maxSec}sec, sizeLimit=#{@sizeLimit/1000}MB",false)
			end
		}
		return errList
	end

public
	def parsingKNP(iPath, xPath, kPath=nil)
		MCMD::mkDir(xPath)
		MCMD::mkDir(kPath) if kPath
		parsing(iPath, xPath, kPath, false)
	end

	def parsingJUM(iPath, xPath, kPath=nil)
		MCMD::mkDir(xPath)
		MCMD::mkDir(kPath) if kPath
		parsing(iPath, xPath, kPath, true)
	end

end # class end

########################## Module end
end

