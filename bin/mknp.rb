#!/usr/bin/env ruby
# encoding:utf-8

require 'rubygems'
require 'nysol/mcmd'
require "nysol/tm"
require "rexml/document"

# 1.1: -file追加
$version="1.1"

def help
cmd=$0.sub(/.*\//,"")
STDERR.puts <<EOF
----------------------------
#{cmd} version #{$version}
----------------------------
概要) テキストファイルで与えられた複数の文書ファイルをKNPで解析し、
用法) #{cmd} I= O= [P=] [mp=2] [log=] [-mcmdenv]
結果をXML構造で出力する。並列処理も可能である。
  I=   : 文書ファイルが格納されたパス名
       : -fileを指定すれば文章ファイル名
  O=   : parsingされたXMLファイルを格納するパス名
  P=   : knpが直接出力する結果を格納するパス名(省略時は出力しない)
  mp=  : 並列処理の数
  log= : KNPが出力するエラーログを格納するファイル名
  -file: I=をパスではなくファイル名として指定する。

  -mcmdenv : 内部で利用しているMCMDのメッセージ出力レベルを環境変数に任せる。
             省略時は警告とエラーメッセージのみ出力(KG_VerboseLeve=2)。

必要なソフトウェア)
  juman7.0, knp4.11
  jumanのインストールは以下のURLより行う。
  http://nlp.ist.i.kyoto-u.ac.jp/index.php?JUMAN
  knpのインストールは以下のURLより行う。
	http://nlp.ist.i.kyoto-u.ac.jp/index.php?KNP

データ内容)
1) 【入力】文書ファイル(I=で指定したパスにあるファイル)
  一行に一文章を基本とする。複数の文章でもよいが、出力されるsidは同一となる。
  例:test.txt
  子どもはリンゴがすきです。
  望遠鏡で泳ぐ少女を見た。

2) 【出力】xmlファイル(O=で指定したパスにできるファイル)
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

3) 【出力】knpの出力ファイル(P=で指定したパスにできるファイル)
  knpが直接出力するデータをまとめたもの。
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
args=MCMD::Margs.new(ARGV,"I=,O=,P=,mp=,log=,-file,-mcmdenv","I=,O=")

iPath = args.file("I=","r")
oPath = args.file("O=","w")
pPath = args.file("P=","w")
mp    = args.int("mp=",2,1,100)
logFile= args.file("log=","w") if args.str("log=")
fileFlg= args.bool("-file")

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

# knpコマンド実行可能確認
cmd=`knp -v 2>&1`
if cmd and not cmd.chomp=~/knp 4/
	MCMD::errorLog("cannot execute knp 4.xx; #{args.cmdline}")
	exit(1)
end

MCMD::mkDir(oPath)
MCMD::mkDir(pPath) if pPath

# knp parsing実行
unless fileFlg
  knp = TM::KNP.new(mp)
  errList=knp.parsingKNP(iPath,oPath,pPath)
else
	tp=MCMD::Mtemp.new
	tiPath = tp.file
	MCMD::mkDir(tiPath)
	system "cp #{iPath} #{tiPath}"
	knp = TM::KNP.new(mp)
	errList=knp.parsingKNP(tiPath,oPath,pPath)
end


# knpのエラーログを出力(なければ0バイトファイル)
if logFile then
	File.open(logFile,"w"){|err|
		err.puts errList
	}
end

# 終了メッセージ
MCMD::endLog(args.cmdline)

