#!/usr/bin/env ruby
# encoding:utf-8

require 'rubygems'
require 'nysol/mcmd'
require 'open3'
require 'thwait'
require 'nysol/lock.rb'

$version = "1.0"
$enju_prefix = ""
$enju_cmd = "enju"

PORT_NO_BASE = 10000

def help
  cmd=$0.sub(/.*\//,"")
  STDERR.puts <<EOF
----------------------------
#{cmd} version #{$version}
----------------------------
概要)enju_serverを起動する。menju.rbを実行する前に実行する。
稼働中のenju_serverがあれば停止してから再起動する。
enju_serverはhttpサーバーとして起動する。使用するポートは#{PORT_NO_BASE}〜。
enjuをインストールしたパスを環境変数ENJU_PREFIXで指定する(PATHを通していれば不要)。
$ export ENJU_PREFIX=/enju_path/
用法)  #{cmd} [mp=2] [-fast] [-detach] [-mcmdenv]
  mp=  : 並列処理の数
  -fast    : 軽量版enju(mogura)を実行する
  -detach  : enju_serverをバックグラウンドで起動する。
  -mcmdenv : 内部で利用しているMCMDのメッセージ出力レベルを環境変数に任せる。
             省略時は警告とエラーメッセージのみ出力(KG_VerboseLevel=2)。

  #{cmd} -shutdown
  -shutdown: バックグラウンドで起動したenju_serverを停止する。

  #{cmd} -reset
  -reset   : enju_serverを強制終了する（挙動がおかしくなった時に使用）。


必要なソフトウェア)
  enju 2.4.2 (その他のバージョンは未確認)
  enjuのインストールは以下のURLに従って行う。
  http://www.nactem.ac.uk/enju/index.ja.html#download
EOF
  exit
end

def ver
  STDERR.puts "version #{$version}"
  exit
end

def clean_enju
  ret = `ps ax|grep -E '(enju|mogura) -cgi'|grep -v sh|grep -v grep`
  ret.each_line do |line|
    prc = line.split(" ")
    Process.kill("INT",prc[0].to_i)
  end
end

def shutdown(force=false)
  clean_enju()
  ret = `ps ax|grep -E 'enju_server.rb'|grep -v sh|grep -v grep`
  ret.each_line do |line|
    prc = line.split(" ")
    signal = force ? "KILL" : "INT"
    Process.kill(signal,prc[0].to_i)
  end
  exit
end

def startup_server(cmdline)
  ENV["ENJU_DETACH"]="1"
  pid = Process.spawn(cmdline)
  Process.detach(pid)
  ENV["ENJU_DETACH"]=nil
  exit
end

#### main ####
help() if ARGV[0]=="--help"
ver() if ARGV[0]=="--version"

# パラメータ設定
begin
  args = MCMD::Margs.new(ARGV,"mp=,-fast,-mcmdenv,-detach,-shutdown,-reset")
rescue
  MCMD::errorLog("Invalid parameter or option")
  abort
end

shutdown() if args.bool("-shutdown")
shutdown(force=true) if args.bool("-reset")
startup_server(args.cmdline.gsub("-detach","")) if args.bool("-detach")

mp = args.int("mp=",2,1,100)
$enju_prefix = ENV["ENJU_PREFIX"] ? ENV["ENJU_PREFIX"]+"/" : ""
$enju_cmd = "mogura" if args.bool("-fast")

# スレッド起動 → enju起動
clean_enju()
# MCMD::msgLog("Press ctrl-C if you want to stop this.") unless ENV["ENJU_DETACH"]
MCMD::msgLog("Starting #{mp} threads")
t = []
mp.times do |cnt|
  t << Thread.new do
    port = PORT_NO_BASE + cnt
    lock = Lock.new("port#{port}")
    lock.lock()
    MCMD::msgLog("Opening port #{port}")
    enju = sprintf("%s%s -cgi %d",$enju_prefix,$enju_cmd,port)
    stdin, stdout, stderr = *Open3.popen3(enju)
    stdin.close
    stderr.each do |line|
      STDERR.print "."
      if line == "Ready\n" then
        lock.close()
        MCMD::msgLog("Port #{port} ready") 
      end
    end
  end
end

# enju起動している間待ち続ける（enjuが落ちるか、Interruptされるまで）
begin
  tw = ThreadsWait.new(*t)
  tw.all_waits do |twa|
    MCMD::errorLog("Enju port down")
    MCMD::errorLog(twa.inspect)
    break
  end
rescue Interrupt
  MCMD::msgLog("Interrupt(ctrl-C) signal detected")
end
clean_enju()
MCMD::endLog(args.cmdline)

