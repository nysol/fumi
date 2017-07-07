#!/usr/bin/env ruby
# encoding:utf-8

require 'rubygems'
require 'nysol/mcmd'

$version="1.3"

# 20160409: 並列処理追加
# 20160405: invalid byte sequence in UTF-8をエラー処理を追加して回避
# 20151103: 読みのnill出力から読みを出力するように変更(jumanの辞書登録で読みが必要)

def help
cmd=$0.sub(/.*\//,"")
STDERR.puts <<EOF
----------------------------
#{cmd} version #{$version}
----------------------------
用法) #{cmd} i= O= [S=5] [n=5] [mp=4] [seed=1]
概要) コーパスから辞書に登録すべき隣接単語ペアの候補情報を出力する。
  i=    : コーパスファイル名
  O=    : 出力ディレクトリ名
  S=    : 単語ペア出現件数最小値
  n=    : 単語ペアごとに出力する文例数
  mp=   : 並列処理の数
	seed= : 乱数の種
	-dai  : 見出し語として代表表記を使う

  -mcmdenv : 内部で利用しているMCMDのメッセージ出力レベルを環境変数に任せる。
             省略時は警告とエラーメッセージのみ出力(KG_VerboseLeve=2)。

実行例)
#{cmd} i=twitter.txt O=twitter_cand

必要なソフトウェア)
  1) juman7.0 (http://nlp.ist.i.kyoto-u.ac.jp/index.php?JUMAN)
	2) nkf (日本語エンコーディング変換ソフト)

解説) テキストファイルで与えられたコーパス(文例)から辞書に登録すべき単語
の入力支援データ(頻出する隣接単語ペアデータと単語ペア出現文例)を以下の手順で出力する。

a) 一行に一文登録されたコーパスデータ(i=にて指定)をJUMANで形態素解析する。
b) その結果から、一定頻度以上共起する隣接単語ペアを出力する(words.csv)。
c) 各単語ペアが出現する文章をコーパスからランダムに指定された件数(n=で指定)選択し、別ファイル(corpus.csv)として出力する。

以上の手順で得られたwords.csvとcorpus.csvから、新たに登録する単語を検討し、
その情報をwords.csvの決められた項目に入力する(後述)。
Excel等Shift_jisを扱うソフトで閲覧したければ、words_sjis.csv、corpus_sjis.csvを使えば良い。
ただし、nkfがインストールされていなければこれらのファイルは出力されない。
また読みが不明の場合は読みに漢字が出力される。

データ内容)
1) コーパス(i=で指定)
一行に一文章を基本とする。複数の文章でもよいが、「共起」は一行における単語ペアの出現と定義される。

2) words.csv
以下の例に示される内容で、新たに登録する単語について「見出し語」〜「ドメイン」までを登録する。
「見出し語」項目は「word1」と「word2」項目を結合した文字列で、登録すべき候補文字列となる。
その他の項目の登録内容については、mcsv2jumandic.rbコマンドのヘルプを参照のこと。

見出し語,品詞,読み,カテゴリ,ドメイン,pid,word1,word2,freq
女性役員,,,,,0,女性,役員,209
野綾子,,,,,1,野,綾子,104
育児休暇,,,,,2,育児,休暇,90
役員比率,,,,,3,役員,比率,62

3) corpus.csv
words.csvで列挙された隣接単語ペアを含む文例をランダムに選択したデータ。
words.csvの「見出し語」を登録すべきかどうかを判断するための資料として参考にすればよい。
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
args=MCMD::Margs.new(ARGV,"i=,O=,S=,n=,mp=,seed=,-dai","i=,O=")

iFile   = args.file("i=","r")
oPath   = args.file("O=","w")
support = args.int("S=",5)
seed    = args.int("seed=",1)
daiFlag = args.bool("-dai")
$mp      = args.int("mp=",2,1,200)


# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")

# jumanコマンド実行可能確認
cmd=`juman -v 2>&1`
if cmd and cmd.chomp!~/juman 7/
	MCMD::errorLog("cannot execute juman 7.0; #{args.cmdline}")
	exit(1)
end

# nkfコマンド実行可能確認
nkf=system("nkf -v >/dev/null")
if not nkf
	MCMD::warningLog("cannot execute nkf, ignored.")
end

MCMD::mkDir(oPath)

def concat(xxwDir,idWord,idCorpus)
		system "mcat i=#{xxwDir}/c_* |mnumber s=pno%n,id%n a=num |mcut f=num:id,text o=#{idCorpus}"
		system "mcat i=#{xxwDir}/w_* |mnumber s=pno%n,id%n a=num e=same |mcut f=num:id,seq,word,yomi o=#{idWord}"
end

# iFileの中身を一行ずつjuman実行し名詞の単語と行番号をoFileに出力する。
# daiFlagがtrueであれば、単語を & 代表表記"から取得する。
def parsing(iFile,idWord,idCorpus,daiFlag)
	MCMD::msgLog("start to parse each line...")
	tf=MCMD::Mtemp.new
	xxjuman=tf.file
	xxsep  =tf.file
	xxwDir =tf.file
	MCMD::mkDir(xxsep)
	MCMD::mkDir(xxwDir)

	cnt = `wc -l #{iFile}`.split[0].to_i
	unit = cnt/$mp +1
	system "split -l #{unit} #{iFile} #{xxsep}/xxa"
	
	Dir["#{xxsep}/xxa*"].meach($mp) {|fn,fno,pno| 
		oCname="#{xxwDir}/c_#{pno}"
		oWname="#{xxwDir}/w_#{pno}"
    eval("@wfc=File.open(oCname,'w')")
		@wfc.puts("pno,id,text")
    eval("@wfw=File.open(oWname,'w')")
		@wfw.puts("pno,id,seq,word,yomi")

		lineNo=0
		File.open(fn,"r"){|fpr|	
			while line=fpr.gets()

				if lineNo%100==0
					MCMD::msgLog("working at line #{lineNo}")
				end

				# xxaの内容
				# 今年 ことし 今年 名詞 6 時相名詞 10 * 0 * 0 "代表表記:今年/ことし カテゴリ:時間"
				# は は は 助詞 9 副助詞 2 * 0 * 0 NIL
				# 少なくとも すくなくとも 少なくとも 副詞 8 * 0 * 0 * 0 "代表表記:少なくとも/すくなくとも 数量修飾"
				# ９９ きゅうきゅう ９９ 名詞 6 数詞 7 * 0 * 0 "カテゴリ:数量"
				# ％ ぱーせんと ％ 接尾辞 14 名詞性名詞助数辞 3 * 0 * 0 "代表表記:％/ぱーせんと 準内容語"
				# の の の 助詞 9 接続助詞 3 * 0 * 0 NIL
				# 販売 はんばい 販売 名詞 6 サ変名詞 2 * 0 * 0 "代表表記:販売/はんばい カテゴリ:抽象物 ドメイン:ビジネス 反義:名詞-サ変名詞:購入/こうにゅう"
				# 増 ぞう 増 名詞 6 普通名詞 1 * 0 * 0 "代表表記:増/ぞう 漢字読み:音 カテゴリ:抽象物"
				# を を を 助詞 9 格助詞 1 * 0 * 0 NIL
				# 確信 かくしん 確信 名詞 6 サ変名詞 2 * 0 * 0 "代表表記:確信/かくしん 補文ト カテゴリ:抽象物"
				# EOS
				text=line.gsub("'","")
				ret=system "echo '#{text}' | juman >#{xxjuman}_#{pno}"

				unless ret
					MCMD::warningLog("Error occured while executing juman, and skipped at line #{lineNo}: #{line}")
					next
				end

				# 参照用コーパスの作成
				text2=text.gsub(",","_").gsub('"',"_")
				@wfc.puts("#{pno},#{lineNo},#{text2}")

				# parsing結果をbufに入れる
				buf=[]
				seq=0
				File.open("#{xxjuman}_#{pno}","r"){|jum|
					while lines=jum.gets()
						begin
							seq+=1
							flds=lines.split(" ")
							next unless flds[3]=="名詞"
							word=flds[0]
							yomi=flds[1]
							if daiFlag
								flds[11]=~/"代表表記:(.*)\//
								word=$1.dup if $1
							end
						rescue
       	      MCMD::warningLog("invalid byte sequence in UTF-8 at line #{lineNo} #{lines}.")
							next
						end
						@wfw.puts("#{pno},#{lineNo},#{seq},#{word},#{yomi}")
					end
					}
					lineNo+=1
				end
			}
   @wfc.close; @wfw.close
	 }
	 concat(xxwDir,idWord,idCorpus)
end

def calFreq(idWord,idCorpus,oWords,oCorpus,support,seed)
	tf=MCMD::Mtemp.new
	xxa=tf.file
	xxt=tf.file
	xxp=tf.file

	# 隣接する単語ペアデータの作成
	f=""
	f << "mslide k=id s=seq%n f=seq:seq2,word:word2,yomi:yomi2 i=#{idWord} |"
	f << "msel   c='abs(${seq}-${seq2})==1' |"
	f << "mcut   f=id,word:word1,word2,yomi:yomi1,yomi2 |"
	f << "msortf f=id,word1,word2 |"
	f << "muniq  k=id,word1,word2 o=#{xxa}"
	system(f)

	# 出現件数表作成
	f=""
	f << "mcut f=word1,word2,yomi1,yomi2 i=#{xxa} |"
	f << "msortf f=word1,word2 |"
	f << "mcount k=word1,word2 a=freq |"
	f << "msel c='${freq}>=#{support}' |"
	f << "msortf f=freq%rn |"
	f << "mnumber s=freq%rn a=pid |"
	f << "mcal c='cat(\"\",$s{word1},$s{word2})' a=見出し語 |"
	f << "mcal c='cat(\"\",$s{yomi1},$s{yomi2})' a=読み |"
	f << "msetstr v=,, a=品詞,カテゴリ,ドメイン |"
	f << "mcut f=見出し語,品詞,読み,カテゴリ,ドメイン,pid,word1,word2,freq o=#{oWords}"
	system(f)

	# パターン別文書例
	# コーパスソーティング
	f=""
	f << "msortf f=id i=#{idCorpus} o=#{xxt}"
	system(f)

	# 出現件数表の単語ペアのみ選択するためのマスター作成
	f=""
	f << "msortf f=word1,word2 i=#{oWords} o=#{xxp}"
	system(f)

	# 単語ペア別に出現する文章をランダムに選択
	f=""
	f << "msortf f=word1,word2 i=#{xxa} |"
	f << "mjoin  k=word1,word2 m=#{xxp} f=pid |"
	f << "mcut   f=pid,id |"
	f << "msortf f=pid,id |"
	f << "mselrand k=pid c=5 S=#{seed} |"
	f << "msortf f=id |"
	f << "mjoin k=id m=#{xxt} f=text |"
	f << "msortf   f=pid%n,id%n o=#{oCorpus}"
	system(f)
end

tf=MCMD::Mtemp.new
xxidWord=tf.file
xxidCorpus=tf.file
xxwords=tf.file
xxcorpus=tf.file

parsing(iFile,xxidWord,xxidCorpus,daiFlag)
calFreq(xxidWord,xxidCorpus,xxwords,xxcorpus,support,seed)
system("mv #{xxwords} #{oPath}/words.csv")
system("mv #{xxcorpus} #{oPath}/corpus.csv")

if nkf
	system("nkf -WsLw <#{oPath}/words.csv >#{oPath}/words_sjis.csv")
	system("nkf -WsLw <#{oPath}/corpus.csv >#{oPath}/corpus_sjis.csv")
end

# 終了メッセージ
MCMD::endLog(args.cmdline)

