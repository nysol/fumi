#!/usr/bin/env ruby
# encoding: utf-8

require "nysol/sentence"

module TM
	#
	# 記事を表すクラス
	#
	class Article
		attr_reader :id
		attr_reader :date
		attr_reader :page
		attr_reader :dummy
		attr_reader :sentences

		def initialize(xml)
			xmlArticle=xml.elements['article']
			@sentences = []
			@dummy     = TM::Sentence.new(nil,self)
			if xmlArticle==nil
				@id=nil
			else
				@id        = xmlArticle.attribute("id").to_s
				@date      = xmlArticle.attribute("date").to_s
				@page      = xmlArticle.attribute("page").to_s
				xmlArticle.elements.each("sentence"){|xmlSentence|
					sentences << TM::Sentence.new(xmlSentence,self)
				}
			end
		end

		# 登録されているsentenceの数を返す
		def size
			return sentences.size
		end

		def tokenCsvout(fp)
			@sentences.each{|sentence|
				sentence.tokenCsvout(fp)
			}
		end

		def phraseCsvout(fp)
			@sentences.each{|sentence|
				sentence.phraseCsvout(fp)
			}
		end

		def phraseEntryCsvout(fp)
			@sentences.each{|sentence|
				sentence.phraseEntryCsvout(fp)
			}
		end

		def entryCsvout(fp)
			@sentences.each{|sentence|
				sentence.entryCsvout(fp)
			}
		end

		def caseFrame()
			caseFrames = []
			@sentences.each{|sentence|
				cfs=sentence.caseFrame()
				caseFrames.concat(cfs) if cfs
			}
			return caseFrames
		end

		def show(simple=false,fp=STDERR)
			fp.puts "Article @id=#{@id}"
			sentences.each{|sentence|
				sentence.show(simple,fp)
			}
		end
	end
end
