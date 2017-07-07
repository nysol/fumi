#!/usr/bin/env ruby
# encoding:utf-8

require 'rubygems'
require 'nysol/mcmd'
require "nysol/tm"
require "rexml/document"

$version="1.0"

def help

cmd=$0.sub(/.*\//,"")
STDERR.puts <<EOF
----------------------------
#{cmd} version #{$version}
----------------------------
概要) テキストファイルで与えられた複数の文書ファイルをKNPで解析し、
用法) #{cmd} I= O= [P=] [mp=2] [log=] [-mcmdenv]
knpの解析結果から、格フレームを抽出し出力する。
  I=   : mknp.rbでparsingした結果xmlファイルが格納されたパス名
  o=   : 出力する格フレームファイル名
  -key : key型フォーマットで出力する。

  -mcmdenv : 内部で利用しているMCMDのメッセージ出力レベルを環境変数に任せる。
             省略時は警告とエラーメッセージのみ出力(KG_VerboseLeve=2)。

必要なソフトウェア)

データ内容)
1) 【入力】mknp.rbで出力される以下のようxmlファイル
<?xml version='1.0' encoding='UTF-8'?>
<article id='test.txt'>
  <sentence id='0' text='子どもはリンゴがすきです。'>
    <chunk id='0' link='2' phraseType='格助詞句' caseType='ガ２格' phrase='子供' phraseTok='子ども' rawPhrase='子どもは'>
      <token id='0' class1='名詞' class2='普通名詞' word='子ども' orgWord='子ども' category='人'/>
      <token id='1' class1='助詞' class2='副助詞' word='は' orgWord='は'/>
    </chunk>
    <chunk id='1' link='2' phraseType='格助詞句' caseType='ガ格' phrase='林檎' phraseTok='リンゴ' rawPhrase='リンゴが'>
      <token id='2' class1='名詞' class2='普通名詞' word='リンゴ' orgWord='リンゴ' category='植物;人工物-食べ物' domain='料理・食事'/>
      <token id='3' class1='助詞' class2='格助詞' word='が' orgWord='が'/>
    </chunk>
    <chunk id='2' link='-1' phraseType='用言句' phraseTok='すきだ' rawPhrase='すきです。' phrase='好きだ'>
      <token id='4' class1='形容詞' class3='ナ形容詞' class4='デス列基本形' word='すきだ' orgWord='すきです'/>
      <token id='5' class1='特殊' class2='句点' word='。' orgWord='。'/>
    </chunk>
  </sentence>
  <sentence id='1' text='望遠鏡で泳ぐ少女を見た。'>
    <chunk id='0' link='3' phraseType='格助詞句' caseType='デ格' phrase='望遠鏡' phraseTok='望遠鏡' rawPhrase='望遠鏡で'>
      <token id='0' class1='名詞' class2='普通名詞' word='望遠' orgWord='望遠' category='抽象物'/>
      <token id='1' class1='名詞' class2='普通名詞' word='鏡' orgWord='鏡' category='人工物-その他' domain='家庭・暮らし'/>
      <token id='2' class1='助詞' class2='格助詞' word='で' orgWord='で'/>
    </chunk>
    <chunk id='1' link='2' phraseType='用言句' phrase='泳ぐ' phraseTok='泳ぐ' rawPhrase='泳ぐ'>
      <token id='3' class1='動詞' class3='子音動詞ガ行' class4='基本形' word='泳ぐ' orgWord='泳ぐ'/>
    </chunk>
    <chunk id='2' link='3' phraseType='格助詞句' caseType='ヲ格' phrase='少女' phraseTok='少女' rawPhrase='少女を'>
      <token id='4' class1='名詞' class2='普通名詞' word='少女' orgWord='少女' category='人'/>
      <token id='5' class1='助詞' class2='格助詞' word='を' orgWord='を'/>
    </chunk>
    <chunk id='3' link='-1' phraseType='用言句' phraseTok='見る' rawPhrase='見た。' phrase='見る'>
      <token id='6' class1='動詞' class3='母音動詞' class4='タ形' word='見る' orgWord='見た'/>
      <token id='7' class1='特殊' class2='句点' word='。' orgWord='。'/>
    </chunk>
  </sentence>

2) 【出力】格フレームをCSVフォーマットで出力したもの
2-1) -keyを指定しない場合、用言と格助詞句のペアとして出力する
項目の意味は以下のとおり。
aid:article ID, sid: sentence ID, cid: chunk ID, contrastConj: 逆接接続詞のsentense, denial: 否定語を伴うchunk
declinableWord: 用言句, lid:格助詞句のchunk ID, caseWord: 格助詞句,case:格助詞句のタイプ

aid,sid,cid,contrastConj,denial,declinableWord,lid,caseWord,case
test.txt,0,2,,,すきだ,0,子ども_ガ２,ガ２
test.txt,0,2,,,すきだ,1,リンゴ_ガ,ガ
test.txt,1,3,,,見る,0,望遠鏡_デ,デ
test.txt,1,3,,,見る,2,少女_ヲ,ヲ
test.txt,2,2,,,いる,0,にわ_ニ,ニ
test.txt,2,2,,,いる,1,はにわにわとり_ガ,ガ
test.txt,3,1,,,泳ぐ,0,クロール_デ,デ
test.txt,3,3,,,見る,2,少女_ヲ,ヲ

2-2) -keyを指定した場合、一つの用言にかかる格助詞句をkey形式で出力する。
aid,sid,cid,contrastConj,denial,lid,word,type
test.txt,0,2,,,2,すきだ,用言
test.txt,0,2,,,0,子ども_ガ２,ガ２
test.txt,0,2,,,1,リンゴ_ガ,ガ
test.txt,1,1,,,1,泳ぐ,用言
test.txt,1,3,,,3,見る,用言
test.txt,1,3,,,0,望遠鏡_デ,デ
test.txt,1,3,,,2,少女_ヲ,ヲ
test.txt,2,2,,,2,いる,用言
test.txt,2,2,,,0,にわ_ニ,ニ
test.txt,2,2,,,1,はにわにわとり_ガ,ガ
test.txt,3,1,,,1,泳ぐ,用言
test.txt,3,1,,,0,クロール_デ,デ
test.txt,3,3,,,3,見る,用言
test.txt,3,3,,,2,少女_ヲ,ヲ
EOF
exit
end

def ver()
	STDERR.puts "version #{$version}"
	exit
end

help() if ARGV.size <= 0 or ARGV[0]=="--help"
ver() if ARGV[0]=="--version"

# パラメータ設定
args=MCMD::Margs.new(ARGV,"I=,o=,mp=,-key,-mcmdenv","I=,o=")

iPath = args.file("I=","r")
oFile = args.file("o=","w")
mp    = args.int("mp=",2,1,100)
key   = args.bool("-key")

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

sCount=0 # メッセージ出力用カウンタ

csv1=nil
if key
	csv1=MCMD::Mcsvout.new("o=#{oFile} f=aid,sid,cid,contrastConj,denial,lid,word,type")
else
	csv1=MCMD::Mcsvout.new("o=#{oFile} f=aid,sid,cid,contrastConj,denial,declinableWord,lid,caseWord,case")
end

# xmlから必要な項目を抜き出す。
Dir["#{iPath}/*"].each{|iFile|
	File.open(iFile,'r'){|fp|
		xml=REXML::Document.new(File.new("#{iFile}"))
		article=TM::Article.new(xml)
		articleID="#{article.id}"

		# 各フレームの取得
		article.sentences.each {|sentence|
			outChunk=[] # 出力したchunk IDを記録する。後で格フレーム以外のchunkを出力するため。
			sentence.chunks.each {|chunk|
				advConj=""
				advConj=1 if chunk.isRevConjunction # 逆接続詞
				denial =""
				denial =1 if chunk.isDenial
				if chunk.phraseType=="用言句" then
					outChunk << chunk.id
					base=[]
					base << articleID
					base << sentence.id
					base << chunk.id
					base << advConj
					base << denial
					you = chunk.phraseTok
					link = []
					chunk.linked.each{|linkedChunk|
						#if linkedChunk.phraseType=="格助詞句" and linkedChunk.caseType!="修飾格" and linkedChunk.caseType!="時間格" then
						if linkedChunk.phraseType=="格助詞句" then
							outChunk << linkedChunk.id
							ct=linkedChunk.caseType.sub('格','')
							link << [linkedChunk.id, linkedChunk.phraseTok, ct]
						end
					}
					if key then # key型の出力
						oFlds=base.dup
						oFlds << chunk.id
						oFlds << you
						oFlds << "用言"
						csv1.write(oFlds)
						link.each{|cf|
							oFlds=base.dup
							oFlds << cf[0]
							oFlds << cf[1]
							oFlds << cf[2]
							csv1.write(oFlds)
						}
					else
						link.each{|cf|
							oFlds=base.dup
							oFlds << you
							oFlds << cf[0]
							oFlds << cf[1]
							oFlds << cf[2]
							csv1.write(oFlds)
						}
					end
				end
			} # chunk.each

			if key then # key型出力のときのみOTHERを出力
      	# 格フレーム以外の出力
				sentence.chunks.each {|chunk|
					next if outChunk.index(chunk.id)

					advConj=""
					advConj=1 if chunk.isRevConjunction # 逆接続詞
					denial =""
					denial =1 if chunk.isDenial
					flds=[]
					flds << articleID
					flds << sentence.id
					flds << chunk.id
					flds << advConj
					flds << denial
					flds << chunk.phraseTok
					flds <<	"#{chunk.phraseTok}_OTHER"
					flds << "OTHER"
					csv1.write(flds)
				}
			end
		sCount+=1
		MCMD::msgLog("#{sCount}th sentence was done.") if sCount%100==0
		}
	}
}

csv1.close
# 終了メッセージ
MCMD::endLog(args.cmdline)

