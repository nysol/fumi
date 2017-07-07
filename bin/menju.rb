#!/usr/bin/env ruby
# encoding:utf-8

require 'rubygems'
require 'nysol/mcmd'
require "rexml/document"
require 'rexml/formatters/pretty'
require 'fileutils'
require 'net/http'
require 'uri'
require 'nysol/lock.rb'

$version = "1.0"
PORT_NO_BASE = 10000

def help
  cmd=$0.sub(/.*\//,"")
  STDERR.puts <<EOF
----------------------------
#{cmd} version #{$version}
----------------------------
概要)テキストファイルで与えられた複数の文書ファイルをenjuで解析し、結果をXML構造で出力する。並列処理も可能である。
バックグラウンド・プロセス(enju_server)を起動する。以降、明示的に停止するまで稼動し続ける。
enjuコマンドのあるパスを環境変数ENJU_PATHで指定する(PATHを通していれば不要)。
$ export ENJU_PATH=/enju_path/
用法)  #{cmd} I= O= [mp=2] [log=] [-pretty] [-mcmdenv]
  I=   : 文書ファイルが格納されたパス名
  O=   : parsingされたXMLファイルを格納するパス名
  mp=  : 並列処理の数
  log= : 実行ログを格納するファイル名
  -pretty  : XMLを整形して出力する。
  -mcmdenv : 内部で利用しているMCMDのメッセージ出力レベルを環境変数に任せる。
             省略時は警告とエラーメッセージのみ出力(KG_VerboseLeve=2)。

  #{cmd} -shutdown
  -shutdown   : バックグラウンドプロセスを停止する。

  #{cmd} -reset
  -reset   : menju.rb環境をリセットする（挙動がおかしくなった時に使用）。

必要なソフトウェア)
  enju_serverで以下のソフトウェアを使用する。
  enju 2.4.2 (その他のバージョンは未確認)
  enjuのインストールは以下のURLより行う。
  http://www.nactem.ac.uk/enju/index.ja.html#download

データ内容)
1) 【入力】文書ファイル(I=で指定したパスにあるファイル)
  一行に一文章を基本とする。複数の文章でもよいが、出力されるsentence idは同一となる。
  例:test.txt
  He runs the company.
  The company that he runs is small.

2) 【出力】xmlファイル(O=で指定したパスにできるファイル)
  articleとsentenceのidには、ぞれぞれ入力文書ファイルのファイル名、
  article内でのシーケンス番号が入る。(articleとsentence以外のidは意味はない)
  sentence parse_statusには、enjuでの実行結果が入る。(ログで出力するものと同じ)
  例:test.xml (-prettyオプションあり)
<article id='test'>
 <sentence id='1' parse_status='success' fom='-0.00412469'>
  <cons id='c22906' cat='S' xcat='' head='c22908' sem_head='c22908' schema='subj_head'>
   <cons id='c22907' cat='NP' xcat='' head='t10780' sem_head='t10780'>
    <tok id='t10780' cat='N' pos='PRP' base='he' lexentry='[&lt;NP.3sg.nom&gt;]' pred='noun_arg0'>
     He
    </tok>
   </cons>
   <cons id='c22908' cat='VP' xcat='' head='c22909' sem_head='c22909' schema='head_comp'>
    <cons id='c22909' cat='VX' xcat='' head='t10781' sem_head='t10781'>
     <tok id='t10781' cat='V' pos='VBZ' base='run' lexentry='[NP.nom&lt;V.bse&gt;NP.acc]-singular3rd_verb_rule' pred='verb_arg12' tense='present' aspect='none' type='none' voice='active' aux='minus' arg1='c22907' arg2='c22910'>
      runs
     </tok>
    </cons>
    <cons id='c22910' cat='NP' xcat='' head='c22912' sem_head='c22912' schema='spec_head'>
     <cons id='c22911' cat='DP' xcat='' head='t10782' sem_head='t10782'>
      <tok id='t10782' cat='D' pos='DT' base='the' lexentry='[&lt;D&gt;]N' pred='det_arg1' type='noun_mod' arg1='c22912'>
       the
      </tok>
     </cons>
     <cons id='c22912' cat='NX' xcat='' head='t10783' sem_head='t10783'>
      <tok id='t10783' cat='N' pos='NN' base='company' lexentry='[D&lt;N.3sg&gt;]' pred='noun_arg0'>
       company
      </tok>
     </cons>
    </cons>
   </cons>
  </cons>
 </sentence>
 <sentence id='2' parse_status='success' fom='-3.40845'>
  <cons id='c22913' cat='S' xcat='' head='c22923' sem_head='c22923' schema='subj_head'>
   <cons id='c22914' cat='NP' xcat='' head='c22916' sem_head='c22916' schema='spec_head'>
    <cons id='c22915' cat='DP' xcat='' head='t10784' sem_head='t10784'>
     <tok id='t10784' cat='D' pos='DT' base='the' lexentry='[&lt;D&gt;]N' pred='det_arg1' type='noun_mod' arg1='c22916'>
      The
     </tok>
    </cons>
    <cons id='c22916' cat='NX' xcat='' head='c22917' sem_head='c22917' schema='head_relative'>
     <cons id='c22917' cat='NX' xcat='' head='t10785' sem_head='t10785'>
      <tok id='t10785' cat='N' pos='NN' base='company' lexentry='[D&lt;N.3sg&gt;]' pred='noun_arg0'>
       company
      </tok>
     </cons>
     <cons id='c22918' cat='S' xcat='REL' head='c22920' sem_head='c22920' schema='filler_head'>
      <cons id='c22919' cat='NP' xcat='REL' head='t10786' sem_head='t10786'>
       <tok id='t10786' cat='N' pos='IN' base='that' lexentry='N.3sg/[&lt;NP.3sg&gt;]' pred='relative_arg1' arg1='c22917'>
        that
       </tok>
      </cons>
      <cons id='c22920' cat='S' xcat='TRACE' head='c22922' sem_head='c22922' schema='subj_head'>
       <cons id='c22921' cat='NP' xcat='' head='t10787' sem_head='t10787'>
        <tok id='t10787' cat='N' pos='PRP' base='he' lexentry='[&lt;NP.3sg.nom&gt;]' pred='noun_arg0'>
         he
        </tok>
       </cons>
       <cons id='c22922' cat='VP' xcat='TRACE' head='t10788' sem_head='t10788'>
        <tok id='t10788' cat='V' pos='VBZ' base='run' lexentry='[NP.nom&lt;V.bse&gt;NP.acc]-movement_rule-singular3rd_verb_rule' pred='verb_arg12' tense='present' aspect='none' type='none' voice='active' aux='minus' arg1='c22921' arg2='c22917'>
         runs
        </tok>
       </cons>
      </cons>
     </cons>
    </cons>
   </cons>
   <cons id='c22923' cat='VP' xcat='' head='c22924' sem_head='c22924' schema='head_comp'>
    <cons id='c22924' cat='VX' xcat='' head='t10789' sem_head='t10789'>
     <tok id='t10789' cat='V' pos='VBZ' base='be' lexentry='[NP.nom&lt;V.cpl.bse&gt;ADJP]_sctl-singular3rd_verb_rule' pred='verb_arg12' tense='present' aspect='none' type='none' voice='active' aux='copular' arg1='c22914' arg2='c22925'>
      is
     </tok>
    </cons>
    <cons id='c22925' cat='ADJP' xcat='' head='t10790' sem_head='t10790'>
     <tok id='t10790' cat='ADJ' pos='JJ' base='small' lexentry='[NP.nom&lt;ADJP&gt;]' pred='adj_arg1' type='pred' arg1='c22914'>
      small
     </tok>
    </cons>
   </cons>
  </cons>
 </sentence>
</article>
EOF
  exit
end

def ver
  STDERR.puts "version #{$version}"
  exit
end

def query_param(text)
  text.gsub!(/\n/,"")
  text.gsub!(/\.$/,"")
  text.gsub!(/^ +/,"")
  text.gsub!(/ +$/,"")
  text.gsub!(/ +/," ")
  text.gsub!(/\?/,"")
  text.gsub!(" ","+")
  text = URI.encode(text)
  text = URI.escape(text)
  return text
end

def enju_parse(text,port_no)
  begin
    res = Net::HTTP.start("localhost", port_no) do |http|
      http.get("/cgi-lilfes/enju?sentence="+query_param(text))
    end
  rescue
  end
  return res
end

def is_fast
  ret = `ps ax|grep -E '(enju|mogura) -cgi'|grep -v sh|grep -v grep`
  return true  if ret =~ /mogura/
  return false if ret =~ /enju/
end

def dir_name(file_name)
  return File::dirname(file_name.split(" ")[0])
end

def check_enju_server(mp)
  mp.times do |cnt|
    port_no = PORT_NO_BASE + cnt
    res = enju_parse("This is a ping message",port_no)
    if not res then # サーバーが起動していない場合
      MCMD::warningLog("Enju server (port:#{port_no}) is not ready.")
      return false
    end
    if res.code == "200" then # サーバーが正常に稼動
      # MCMD::msgLog("Enju server (port:#{port_no}) is ready")
    else
      # MCMD::warningLog("Enju server (port:#{port_no}) is not ready.")
      return false
    end
  end
  return true
end

def startup_enju_server(path,mp,fast)
  MCMD::msgLog("(Re)starting enju server")
  mode = fast ? "-fast" : ""
  system "#{path}/enju_server.rb -shutdown"
  system "#{path}/enju_server.rb mp=#{mp} #{mode} -detach"
  sleep 5
  
  mp.times do |cnt|
    port_no = PORT_NO_BASE + cnt
    lock = Lock.new("port#{port_no}")
    lock.lock()
    lock.close()
  end
end

def shutdown_enju_server(path)
  MCMD::msgLog("Shuting down enju server")
  system "#{path}/enju_server.rb -shutdown"
end

def reset_enju_server(path)
  MCMD::msgLog("Resetting enju server")
  system "#{path}/enju_server.rb -reset"
end

def logging(lFile,text,mode="a")
  MCMD::msgLog(text)
  if lFile then
    File.open(lFile,mode) do |io|
      io.puts text
    end
  end
end


#### main ####
help() if ARGV.size <= 0 or ARGV[0]=="--help"
ver() if ARGV[0]=="--version"

# パラメータ設定
begin
  args=MCMD::Margs.new(ARGV,"I=,O=,mp=,log=,-pretty,-fast,-mcmdenv,-shutdown,-reset")

	# パラチェック（仮）
	if args.bool("-shutdown") then 
	  shutdown_enju_server(dir_name(args.cmdline))
	  exit
	elsif args.bool("-reset") then
	  reset_enju_server(dir_name(args.cmdline))
	  exit
	else
		raise unless args.str("I=") and args.str("O=")
	end
	
rescue
  MCMD::errorLog("Invalid parameter or option")
  abort
end



iPath = args.file("I=","r")
oPath = args.file("O=","w")
mp = args.int("mp=",2,1,100)
logFile = args.file("log=","w") if args.str("log=")

# mcmdのメッセージは警告とエラーのみ
ENV["KG_VerboseLevel"]="2" unless args.bool("-mcmdenv")


# enju実行可能確認(ポート数の不足も含む)
if not check_enju_server(mp) then
  startup_enju_server(dir_name(args.cmdline),mp,args.bool("-fast"))
end

# 稼働中のenju_serverの"-fast"有無と、コマンドの"-fast"有無の相違
if args.bool("-fast") != is_fast() then
  startup_enju_server(dir_name(args.cmdline),mp,args.bool("-fast"))
end

MCMD::mkDir(oPath)

logging(logFile,Time.now.strftime("Start parsing %Y/%m/%d %H:%M:%S"),"w")
logging(logFile,Time.now.strftime("(port_no)article_id #sentence_id:status ..."))

iFiles = Dir.glob("#{iPath}/*")
iFiles.meach(mp) do |iFile,count|
  article_id = File.basename(iFile,".txt")
  enju_cmd = is_fast ? "mogura" : "enju"
  port_no = PORT_NO_BASE + (count % mp)
  
  doc = REXML::Document.new
  doc << REXML::XMLDecl.new('1.0','UTF-8')
  article = doc.add_element("article",{"id"=>article_id,"enju_cmd"=>enju_cmd})
  
  log = "(#{port_no})#{article_id}"
  id = 0
  File.open(iFile,"r") do |io|
    io.each do |line|
      id += 1
      res = enju_parse(line,port_no)
      break unless res
      if res.code == "200"
        sentence = REXML::Document.new(res.body)
        stat = sentence.elements["//sentence"].attributes["parse_status"]
        log << " ##{id.to_s}:#{stat}" ##unless stat == "success"
        
        # sentence.idだけ1からリナンバー
        sentence.elements["//sentence"].attributes["id"] = "s#{id}"
      else
        log << " ##{id.to_s}:HTTP error #{res.code}"
        sentence = REXML::Document.new()
      end
      article.add_element(sentence)
    end
  end
  
  if id >= 1 then
    if args.bool("-pretty") then
      format = REXML::Formatters::Pretty.new(indentation=1)
      out = StringIO.new
      format.write(article,out)
      res = out.string
    else
      res = article
    end
    File.open("#{oPath}/#{article_id}.xml","w") do |io|
      io.write res
    end
  else
    log << " empty"
  end

  logging(logFile,log)
end

# 終了メッセージ
logging(logFile,Time.now.strftime("#END MENJU# %Y/%m/%d %H:%M:%S"))
MCMD::endLog(args.cmdline)
