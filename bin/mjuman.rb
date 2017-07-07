#!/usr/bin/env ruby
# encoding:utf-8

require 'rubygems'
require 'nysol/mcmd'
require "nysol/tm"
require "rexml/document"

# 1.1: i=,o=追加
# 1.2: -file追加
$version="1.2"

def help

cmd=$0.sub(/.*\//,"")
STDERR.puts <<EOF
----------------------------
#{cmd} version #{$version}
----------------------------
概要) テキストファイルで与えられた複数の文書ファイルをJUMANで解析し、その結果をCSVで出力する。並列処理も可能である。
用法) #{cmd} (i= o= p=)|(I= O= P=) [-file] [mp=2] [log=] [-mcmdenv]
  I=   : 文書ファイルが格納されたパス名
       : -fileを指定すれば文書ファイル名
  O=   : parsingされたCSVファイルを格納するパス名
       : I=で指定したディレクトリ以下のファイル名と同名で出力される。
  P=   : jumanが直接出力する結果を格納するパス名(省略時は出力しない)
       : I=で指定したディレクトリ以下のファイル名と同名で出力される。
  i=   : 文書CSVファイル名(フォーマットは1-b)を参照のこと)
  o=   : parsingされたCSVファイル名
  p=   : jumanが直接出力する結果を格納するファイル名(省略時は出力しない)
  mp=  : 並列処理の数
  log= : JUMANが出力するエラーログを格納するファイル名
  -file: I=をパスではなくファイル名として指定する。

  -mcmdenv : 内部で利用しているMCMDのメッセージ出力レベルを環境変数に任せる。
             省略時は警告とエラーメッセージのみ出力(KG_VerboseLeve=2)。

必要なソフトウェア)
  juman7.0
  jumanのインストールは以下のURLより行う。
  http://nlp.ist.i.kyoto-u.ac.jp/index.php?JUMAN


データ内容)
1-a) 【入力】文書ファイル(I=で指定したパスにあるファイル)
  一行に一文章を基本とする。複数の文章でもよいが、出力されるsidは同一となる。
  出力ファイルにおいてファイル名がaidとなり、行番号がsidとなる。
  例:test.txt
  子どもはリンゴがすきです。
  望遠鏡で泳ぐ少女を見た。

1-b) 【入力】文章IDとテキストの2項目からなるCSVファイル(i=で指定したファイル)
  CSVの項目名は任意だが、項目の順序は文章ID、テキストの順でなければならない。
  テキストに改行があってはならない。
  出力ファイルにおいてファイル名がaidとなり、文章IDがsidとなる。
  例:test.csv
  sid,text
  s001,子どもはリンゴがすきです。
  s002,望遠鏡で泳ぐ少女を見た。

2) 【出力】csvファイル(O=で指定したパスにできるCSVファイル、もしくはo=で指定したCSVファイル)
  以下に例示されるような12の項目を出力する。
  ファイル名は入力文書ファイルと同じになる。
  aidはファイル名に対応し、sidは行番号、tidが形態素番号である。
  word,orgWord,daiWordは、いずれも形態素でそれぞれ異なる意味を持つ。
  orgWordは文章中で使われたそのままの表記の語で、wordはその原形である。
  例えば、過去形の「見た」は、orgWordは「見た」でwordは「見る」となる。
  また、表記が複数ある場合はdaiWordに代表表記が出力される。
  これはannotation項目の「代表表記」から切り出した文字列である。
  例えば、リンゴは「りんご」や「林檎」などの表記もあるが、代表表記としては「林檎」となる。
  yomiはかなによる読みを表す。
  class1〜class4は品詞と活用形で、annotationは意味情報である。
  詳しくはJUMANのwebページを参照のこと。
  http://nlp.ist.i.kyoto-u.ac.jp/index.php?JUMAN

  例:上記test.txtに対する出力結果
  aid,sid,tid,word,orgWord,daiWord,yomi,class1,class2,class3,class4,annotation
  test.txt,0,0,子ども,子ども,子供,こども,名詞,普通名詞,,,代表表記:子供/こども カテゴリ:人
  test.txt,0,1,は,は,,は,助詞,副助詞,,,
  test.txt,0,2,リンゴ,リンゴ,林檎,りんご,名詞,普通名詞,,,代表表記:林檎/りんご カテゴリ:植物;人工物-食べ物 ドメイン:料理・食事
  test.txt,0,3,が,が,,が,助詞,格助詞,,,
  test.txt,0,4,すきだ,すきです,好きだ,すきです,形容詞,,ナ形容詞,デス列基本形,代表表記:好きだ/すきだ 反義:形容詞:嫌いだ/きらいだ 動詞派生:好く/すく
  test.txt,0,5,。,。,,。,特殊,句点,,,
  test.txt,1,0,望遠,望遠,望遠,ぼうえん,名詞,普通名詞,,,代表表記:望遠/ぼうえん カテゴリ:抽象物
  test.txt,1,1,鏡,鏡,鏡,かがみ,名詞,普通名詞,,,代表表記:鏡/かがみ 漢字読み:訓 カテゴリ:人工物-その他 ドメイン:家庭・暮らし
  test.txt,1,2,で,で,,で,助詞,格助詞,,,
  test.txt,1,3,泳ぐ,泳ぐ,泳ぐ,およぐ,動詞,,子音動詞ガ行,基本形,代表表記:泳ぐ/およぐ
  test.txt,1,4,少女,少女,少女,しょうじょ,名詞,普通名詞,,,代表表記:少女/しょうじょ カテゴリ:人
  test.txt,1,5,を,を,,を,助詞,格助詞,,,
  test.txt,1,6,見る,見た,見る,みた,動詞,,母音動詞,タ形,代表表記:見る/みる 補文ト 自他動詞:自:見える/みえる
  test.txt,1,7,。,。,,。,特殊,句点,,,

3) 【出力】jumanの出力ファイル(P=で指定したパスにできるファイル)
  jumanが直接出力するデータをまとめたもの。
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
args=MCMD::Margs.new(ARGV,"i=,o=,id=,text=,p=,I=,O=,P=,mp=,log=,-file,-mcmdenv","")

iFile = args.file("i=","r")
oFile = args.file("o=","w")
idFld = args.field("id=", iFile, nil,1,1)
txFld = args.field("text=", iFile, nil,1,1)
iPath = args.file("I=","r")
oPath = args.file("O=","w")
pPath = args.file("P=","w")
pFile = args.file("p=","w")
mp    = args.int("mp=",2,1,100)
logFile= args.file("log=","w") if args.str("log=")
fileFlg= args.bool("-file")

idFld=idFld["names"][0] if idFld
txFld=txFld["names"][0] if txFld

unless iFile or iPath
	raise "i= or I= is mandatory"
end
if iFile and iPath
	raise "i= and I= are exclusive"
end

unless oFile or oPath
	raise "o= or O= is mandatory"
end
if oFile and oPath
	raise "o= and O= are exclusive"
end

if pFile and pPath
	raise "p= and P= are exclusive"
end

if oFile and iPath
	raise "o= must be specified with i="
end
if oPath and iFile
	raise "O= must be specified with I="
end

if iFile and not idFld
	raise "id= is mandatory when i= is specified"
end
if iFile and not txFld
	raise "text= is mandatory when i= is specified"
end

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

# jumanコマンド実行可能確認
cmd=`juman -v 2>&1`
if cmd and cmd.chomp!~/juman 7/
	MCMD::errorLog("cannot execute juman 7.xx; #{args.cmdline}")
	exit(1)
end

MCMD::mkDir(oPath) if oPath
MCMD::mkDir(pPath) if pPath and oPath

def separateData(iFile,idFld,txFld,tiPath,idFile)
	tp=MCMD::Mtemp.new
	xxbase=tp.file

	recSize=MCMD::mrecount("i=#{iFile}")
	oneFileSize=recSize/1000+1 # 1000ファイルに分割したときの1ファイルあたりの行数

	f=""
	f << "mcut    f=#{idFld}:key,#{txFld}:text i=#{iFile} |"
	f << "mcal    c='floor(line()/#{oneFileSize},1)' a=fileNo |"
	f << "mnumber k=fileNo s=key a=seq o=#{xxbase}"
	system(f)
	system "mcut f=key,fileNo,seq i=#{xxbase} o=#{idFile}"

	MCMD::Mcsvin.new("k=fileNo i=#{xxbase}"){|csv|
		fpw=nil
		csv.each{|flds,top,bot|
			text=flds["text"]
			fileNo=flds["fileNo"]
			if top
				fpw=File.open("#{tiPath}/#{fileNo}","w")
			end

			fpw.puts text

			if bot
				fpw.close
			end
		}
	}
end

# juman parsing実行
errList=nil
if iPath
	unless fileFlg
		knp = TM::KNP.new(mp)
		errList=knp.parsingJUM(iPath,oPath,pPath)
	else
		tp=MCMD::Mtemp.new
		tiPath = tp.file
		MCMD::mkDir(tiPath)
		system "cp #{iPath} #{tiPath}"
		knp = TM::KNP.new(mp)
		errList=knp.parsingJUM(tiPath,oPath,pPath)
	end
else
	tp=MCMD::Mtemp.new
	tiPath = tp.file
	toPath = tp.file
	tpPath = tp.file
	idFile = tp.file
	#tiPath = "xxti"
	#toPath = "xxto"
	#tpPath = "xxtp"
	#idFile = "xxid"
	MCMD::mkDir(tiPath)
	MCMD::mkDir(toPath)
	MCMD::mkDir(tpPath)
	# 
	separateData(iFile,idFld,txFld,tiPath,idFile)
	knp = TM::KNP.new(mp)
	errList=knp.parsingJUM(tiPath,toPath,tpPath)
	f=""
	f << "mcat i=#{toPath}/* |"
	f << "mjoin k=aid,sid K=fileNo,seq m=#{idFile} f=key |"
	f << "msetstr v=#{File.basename(iFile)} a=file |"
	f << "mcut f=file:aid,key:sid,tid,word,orgWord,daiWord,yomi,class1,class2,class3,class4,annotation |"
	f << "msortf f=aid,sid,tid%n o=#{oFile}"
	system(f)
	system "cat #{tpPath}/* >#{pPath}" if pPath
end

# knpのエラーログを出力(なければ0バイトファイル)
if logFile then
	File.open(logFile,"w"){|err|
		err.puts errList
	}
end

# 終了メッセージ
MCMD::endLog(args.cmdline)

