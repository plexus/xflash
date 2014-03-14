# -*- coding: utf-8 -*-
require 'pathname'
require 'yaml'
require 'readline'
require 'forwardable'
require 'delegate'

module XFlash
  class DataPoint < Struct.new(:timestamp, :rating)
    MAX_RATING=3

    def neg_rating
      MAX_RATING - rating
    end

    def fail?
      rating == 0
    end
  end

  class CardHistory < DelegateClass(Array)
    EMPTY = new([].freeze)

    extend Forwardable
    def_delegators :card_state, :interval, :iteration, :factor

    def << data_point
      CardHistory.new (self + [data_point]).freeze
    end

    def card_state
      inject(CardState.start, :+)
    end
  end

  class CardState < Struct.new(:iteration, :streak, :factor, :interval)
    INITIAL_INTERVALS = [1, 4]

    def self.start
      new(0, 0, 2.5, 1)
    end

    def +(data_point)
      self.class.new(
        iteration + 1,
        next_streak(data_point),
        next_factor(data_point),
        next_interval(data_point)
      )
    end

    def next_streak(data_point)
      data_point.fail? ? 0 : streak + 1
    end

    def next_factor(data_point)
      [factor + (0.1 - data_point.neg_rating * (0.28 + data_point.neg_rating * 0.02)), 1.3].max
    end

    def next_interval(data_point)
      INITIAL_INTERVALS.fetch(next_streak(data_point)) do
        interval * next_factor(data_point)
      end
    end

    def inspect
      "<CardState iteration: %d, streak: %d, factor: %.2f, interval: %.2f>" % [iteration, streak, factor, interval]
    end
  end

  class Card < Struct.new(:id, :front, :back, :history)
    extend Forwardable
    def_delegators :history, :card_state
    def_delegators :card_state, :factor, :interval

    def rate(rating)
      self.history <<= DataPoint.new(Time.now, rating)
      self
    end

    def inspect
      "<Card #{front} #{card_state.inspect}>"
    end
  end

  FIXTURES = [
    [0, '入選', "(入选) [ru4 xuan3] /to be chosen/to be elected as/"],
    [1, '報名', "(报名) [bao4 ming2] /to sign up/to enter one's name/to apply/to register/to enroll/to enlist/"],
    [2, '訊息', "(讯息) [xun4 xi1] /information/news/message/text message or SMS/"],
    [3, '詢問', "(询问) [xun2 wen4] /to inquire/"],
    [4, '導致', "(导致) [dao3 zhi4] /to lead to/to create/to cause/to bring about/"],
    [5, '琴', "[qin2] /guqin or zither, cf 古琴[gu3 qin2]/musical instrument in general/"],
    [6, '提供', "[ti2 gong1] /to offer/to supply/to provide/to furnish/"],
    [7, '更新', "[geng1 xin1] /to replace the old with new/to renew/to renovate/to upgrade/to update/to regenerate/"],
    [8, '出力', "[chu1 li4] /to exert oneself/"],
    [9, '拌蒜', "[ban4 suan4] /to stagger (walk unsteadily)/"],
  ].map{|args| Card.new(*args, CardHistory::EMPTY)}

  class CardStore
    attr_reader :store

    def initialize
      @store = Store.new
    end
  end

  class Store
    LOCATION = Pathname('~').expand_path.join('.xflash')

    def load
      YAML.load(LOCATION.read)
    end

    def save(data)
      LOCATION.write(YAML.dump(data))
    end
  end

  class App
    attr_reader :card, :cards
    def initialize(cards)
      @cards = cards
    end

    def next_card
      @card = cards.sample
    end

    def rate_card(score)
      puts "Before : " + card.inspect
      card.rate(score)
      puts "After  : " + card.inspect
    end

    def readline_loop
      next_card
      loop do
        input = Readline.readline("#{card.front} > ", true)
        exit unless input
        case input
        when /s/, ""
          puts card.back
        when /[0-5]/
          rate_card(input.to_i)
          next_card
        end
      end
    end
  end
end

XFlash::App.new(XFlash::FIXTURES).readline_loop