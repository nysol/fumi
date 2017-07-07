#!/usr/bin/env ruby
# encoding:utf-8

require 'rubygems'
require 'nysol/mcmd'
$version="1.0"

def help
cmd=$0.sub(/.*\//,"")
STDERR.puts <<EOF
----------------------------
#{cmd} version #{$version}
----------------------------
概要) CSVで与えられた辞書をjumanの辞書に変換
用法) #{cmd} i= O= [exe=] [-mcmdenv]
  i=   : CSVの辞書ファイル名
  O=   : JUMANの辞書を格納するディレクトリ名
  exe= : makeint等のコマンドパス(デフォルトは/usr/local/bin)
         jumanを通常の方法でインストールすれば指定する必要はないはず。

  -mcmdenv : 内部で利用しているMCMDのメッセージ出力レベルを環境変数に任せる。
             省略時は警告とエラーメッセージのみ出力(KG_VerboseLeve=2)。

必要なソフトウェア)
  juman7.0をインストールした時に同時にインストールされる以下のコマンド
  a. /usr/local/libexec/juman/makeint
  b. /usr/local/libexec/juman/dicsort
  c. /usr/local/libexec/juman/makepat
  jumanのインストールは以下のURLより行う。
  http://nlp.ist.i.kyoto-u.ac.jp/index.php?JUMAN

解説) CSVで与えられた見出し語や読みを読み込み、JUMAN7.0用の辞書jumandic.dat、jumandic.patを作成する。
ただし、登録できる品詞は名詞に限る。

データ内容)
1) 【入力】CSVの辞書ファイル
  例:
  id,見出し語,読み,品詞,カテゴリ,ドメイン
  1,連結営業利益,れんけつえいぎょうりえき,普通名詞,抽象物,ビジネス
  2,米国債,べいこくさい,,抽象物,ビジネス
  3,上方修正,じょうほうしゅうせい,サ変名詞,抽象物,ビジネス
  4,日本航空,にほんこうくう,組織名,,
  5,夏目漱石,なつめそうせき,人名,日本,姓
  6,安倍首相 安倍晋太郎 安倍晋太郎首相,あべしゅしょう,人名,日本,姓名
  7,２ちゃんねる にちゃんねる,にちゃんねる,,,

  内容解説:
  a.「品詞,見出し語,読み,カテゴリ,ドメインの5項目が含まれるCSVデータ(上記例id項目は説明用の項目でありなくてもよい)。
  b. これら５つの項目の並び順に決まりはない。
  c. 品詞は名詞のみ対応しており、以下に示す名詞の下位の品詞を「品詞」項目に登録する。
     普通名詞,サ変名詞,時相名詞,数詞,副詞的名詞,固有名詞,人名,組織名,地名
  d. 品詞がnullであれば「普通名詞」が指定されたものとする。
  e. 品詞の体系は以下のURLを参照のこと。
     http://www.unixuser.org/~euske/doc/postag/
  f. 見出し語には、表記ゆれなどの複数の見出し語を半角空白で区切って列挙できる(id=6,7)。
  g. 見出し語に半角が含まれているとエラー
	h. 見出し語もしくは読みがnullならばエラー
  i. カテゴリとドメインは、以下のURLを参考に登録する。わからなければnullにしておく。
     http://nlp.ist.i.kyoto-u.ac.jp/DLcounter/lime.cgi?down=http://nlp.ist.i.kyoto-u.ac.jp/nl-resource/knp/20090930-juman-knp.ppt&name=20090930-juman-knp.ppt
  j. カテゴリは以下の22種
     人,組織・団体,動物,植物,動物-部位,植物-部位,人工物-食べ物,人工物-衣類,人工物-乗り物
     人工物-金銭,人工物-その他,自然物,場所-施設,場所-施設部位,場所-自然,場所-機能
     場所-その他,抽象物,形・模様,色,数量,時間
  k. ドメインは以下の12種
     文化・芸術,交通,レクリエーション,教育・学習,スポーツ,科学・技術,健康・医学
     ビジネス,家庭・暮らし,メディア,料理・食事,政治,ドメイン無し
  l. カテゴリとドメインは、普通名詞とサ変名詞にのみ有効な項目(ただし人名と地名については別用途で利用)。
  m. 詳細は、JUMANのwebページもしくは、JUMANソースコードのdic/*.dicファイルを参照のこと。

2) 出力ファイル
	jumandic.dat, jumandic.pat : JUMANが直接参照する辞書ファイル(makeint,dicsort,makepatコマンドによって生成されるバイナリ) 
	入力ファイルの拡張子を除いた名前.dic: dicフォーマットの辞書(テキストファイル)

	dicファイルの内容例
  (名詞 (サ変名詞 ((読み じょうほうしゅうせい) (見出し語 上方修正) (意味情報 "代表表記:上方修正/じょうほうしゅうせい"))))
  (名詞 (人名 ((読み なつめそうせき) (見出し語 夏目漱石) (意味情報 ""))))
  (名詞 (人名 ((読み あべしゅしょう) (見出し語 安倍首相 安倍晋太郎 安倍晋太郎首相) (意味情報 ""))))
  (名詞 (組織名 ((読み にほんこうくう) (見出し語 日本航空) (意味情報 "代表表記:日本航空/にほんこうくう"))))
  (名詞 (普通名詞 ((読み べいこくさい) (見出し語 米国債) (意味情報 "代表表記:米国債/べいこくさい"))))
  (名詞 (普通名詞 ((読み れんけつえいぎょうりえき) (見出し語 連結営業利益) (意味情報 "代表表記:連結営業利益/れんけつえいぎょうりえき"))))
  (名詞 (普通名詞 ((読み にちゃんねる) (見出し語 ２ちゃんねる にちゃんねる) (意味情報 "代表表記:２ちゃんねる/にちゃんねる"))))
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
args=MCMD::Margs.new(ARGV,"i=,O=,exe=","i=,O=")

iFile = args.file("i=","r")
oPath = args.file("O=","w")
exe   = args.str("exe=","/usr/local/libexec/juman")

exe_makeint="#{exe}/makeint"
exe_dicsort="#{exe}/dicsort"
exe_makepat="#{exe}/makepat"

unless File.executable?(exe_makeint)
	MCMD::errorLog("Command Not Found: #{exe_makeint}. Check if juman Installed.")
	exit(1)
end

unless File.executable?(exe_dicsort)
	MCMD::errorLog("Command Not Found: #{exe_dicsort}. Check if juman Installed.")
	exit(1)
end

unless File.executable?(exe_makepat)
	MCMD::errorLog("Command Not Found: #{exe_makepat}. Check if juman Installed.")
	exit(1)
end

MCMD::mkDir(oPath)

tf=MCMD::Mtemp.new
xxdic=tf.file

f=""
f << "mcut   f=品詞,見出し語,読み i=#{iFile} |"
f << "mdelnull f=見出し語,読み |"
f << "msortf f=見出し語 |"
f << "muniq  k=見出し語 o=#{xxdic}"
system(f)

body=""
File.open("xxusr.dic","w"){|fpw|
	line=0
	MCMD::Mcsvin.new("i=#{xxdic}"){|csv|
		csv.each{|flds|
			cls=flds['品詞']
			cls="普通名詞" unless cls
			mid=flds['見出し語']
			yom=flds['読み']
			cat=flds['カテゴリ']
			dom=flds['ドメイン']
			unless mid
				MCMD::errorLog("Field '見出し語' has null value at line ##{line}; #{args.cmdline}")
				exit(1)
			end
			if /[!-~]/=~mid
				MCMD::errorLog("Field '見出し語' cannot take HANKAKU charactor at line ##{line}; #{mid}; #{args.cmdline}")
				exit(1)
			end
			mid=mid.split(" ")

			unless yom
				MCMD::errorLog("Field 'YOMI' has null value at line ##{line}.")
				exit(1)
			end

			sem=""
			if cls!="人名"
				sem << "代表表記:#{mid[0]}/#{yom}"
			else # 人名は代表表記なし
				sem << "人名:#{dom}" if dom
			end

			if cls=="普通名詞" or cls=="サ変名詞"
				sem << " カテゴリ:#{cat}" if cat
				sem << " ドメイン:#{dom}" if dom
			elsif cls=="地名"
				sem << "地名:#{dom}" if dom
			end

			# (名詞 (普通名詞 ((読み あいしゃ)(見出し語 愛車 (あい車 1.6) (あいしゃ 1.6))(意味情報 "代表表記:愛車/あいしゃ カテゴリ:人工物-乗り物 ドメイン:交通"))))
			# (名詞 (サ変名詞 ((読み けっさん)(見出し語 決算 (けっさん 1.6))(意味情報 "代表表記:決算/けっさん カテゴリ:抽象物 ドメイン:ビジネス"))))
			# (名詞 (人名 ((読み すずき)(見出し語 鈴木)(意味情報 "人名:日本:姓:1:0.00961"))))
			# (名詞 (地名 ((読み ほっかいどう)(見出し語 北海道 (ほっかいどう 1.6))(意味情報 "代表表記:北海道/ほっかいどう 地名:日本:道"))))
			# (名詞 (組織名 ((読み あいびーえむ)(見出し語 アイビーエム)(意味情報 "代表表記:アイビーエム/あいびーえむ"))))
			# (名詞 (固有名詞 ((読み しょうそういん)(見出し語 正倉院)(意味情報 "代表表記:正倉院/しょうそういん"))))
			fpw.puts "(名詞 (#{cls} ((読み #{yom}) (見出し語 #{mid.join(' ')}) (意味情報 \"#{sem}\"))))"

		}
		line+=1
	}
}

system "mv xxusr.dic #{oPath}/jumandic.dic"
system "cd #{oPath} ; #{exe_makeint} jumandic.dic"
system "cd #{oPath} ; #{exe_dicsort} jumandic.int > jumandic.dat"
system "cd #{oPath} ; #{exe_makepat} jumandic.int"

MCMD::msgLog("#{oPath}内のjumandic.dat,jumandic.patの２つのファイルがユーザ辞書として必要となる。",false)
MCMD::msgLog("~/.jumanrcファイルを編集し、これらのファイルが格納されたパス名を以下のように追加登録する。",false)
MCMD::msgLog("(辞書ファイル",false)
MCMD::msgLog("        /usr/local/share/juman/dic",false)
MCMD::msgLog("        /usr/local/share/juman/autodic",false)
MCMD::msgLog("        /usr/local/share/juman/wikipediadic",false)
MCMD::msgLog("        #{File.expand_path(oPath)}",false)
MCMD::msgLog(")",false)

# 終了メッセージ
MCMD::endLog(args.cmdline)
