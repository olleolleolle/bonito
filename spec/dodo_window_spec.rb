# frozen_string_literal: true

require 'active_support/core_ext/numeric/time'
require 'securerandom'

RSpec.describe Dodo::Window do
  let(:duration) { 2.weeks }
  let(:window) { Dodo::Window.new(duration) {} }
  let(:moment) { Dodo::Moment.new {} }
  let(:block) { -> { true } }

  describe '#initialize' do
    let(:uninitialized) { Dodo::Window.allocate }

    subject { window }

    it 'should set duration' do
      expect(subject.duration).to eq duration
    end

    it 'should initialize @happenings as an empty array' do
      expect(subject.instance_variable_get(:@happenings)).to eq []
    end

    it 'should initialize @total_child_duration as 0' do
      expect(subject.instance_variable_get(:@total_child_duration)).to eq 0
    end

    it 'should invoke instance_eval' do
      expect(uninitialized).to receive(:instance_eval) do |&blk|
        expect(blk).to eq block
      end
      uninitialized.send(:initialize, duration, &block)
    end
  end

  describe '#push' do
    subject { window.send :push, happening }

    context 'with a happening whose duration is less than that of the window' do
      let(:happening) { Dodo::Window.new(duration - 1) {} }

      it 'should successfully append the happening' do
        expect(subject.instance_variable_get(:@happenings)).to eq [happening]
      end

      it 'should increase the @total_child_duration by the duration of the happening' do
        expect { subject }.to change {
          window.instance_variable_get :@total_child_duration
        }.by happening.duration
      end
    end

    context 'with a happening whose duration is greater than that of the window' do
      let(:happening) { Dodo::Window.new(duration + 1) {} }

      it 'should successfully append the happening' do
        expect { subject }.to raise_error(Exception)
      end
    end
  end

  describe '#use' do
    it 'should be an alias for #push_window' do
      expect(window.method(:use)).to eq(window.method(:push_window))
    end
  end

  describe '#over' do
    let(:child) { Dodo::Window.new(duration - 1) {} }

    before do
      allow(window.class).to receive(:new).and_return child
    end

    subject { window.over(child.duration, &block) }

    it 'should instantiate a new child' do
      expect(window.class).to receive(:new) do |dur, &blk|
        expect(dur).to eq child.duration
        expect(blk).to eq block
        child
      end
      subject
    end

    it 'should append the new window to parent@happenings' do
      expect(window).to receive(:push_window).with(child)
      subject
    end

    it 'should return the child' do
      expect(subject).to eq child
    end
  end

  describe 'please' do
    before do
      allow(Dodo::Moment).to receive(:new).and_return(moment)
    end

    subject { window.please(&block) }

    it 'should instantiate a new child' do
      expect(Dodo::Moment).to receive(:new) do |&blk|
        expect(blk).to eq block
        moment
      end
      subject
    end

    it 'should append the new window to window@happenings' do
      expect(window).to receive(:push_moment).with(moment)
      subject
    end

    it 'should return the moment' do
      expect(subject).to eq moment
    end
  end

  describe '#repeat' do
    before do
      allow(window).to receive(:please).and_return(moment)
    end

    context 'with no args and passing block' do
      subject { window.repeat &block }
      it 'should invoke #please twice passing block' do
        expect(window).to receive(:please) do |&blk|
          expect(blk).to eq block
        end.exactly(2).times
        subject
      end

      it 'should return an array of Moments' do
        expect(subject).to eq [moment, moment]
      end
    end

    context 'with an integer as the :times argument and passing block' do
      let(:k) { 3 }

      subject { window.repeat times: k, &block }

      it 'should invoke #please :repetitions times passing block' do
        expect(window).to receive(:please) do |&blk|
          expect(blk).to eq block
        end.exactly(k).times
        subject
      end
    end
  end
end
RSpec.describe Dodo::Moment do
  let(:block) { proc { p 'some block' } }
  let(:moment) { Dodo::Moment.new &block }
  describe '#initialize' do
    subject { moment }
    context 'when passed a block' do
      it 'should initialize successfully' do
        subject
      end
    end
  end
  describe '#duration' do
    subject { moment.duration }
    it 'should return 0' do
      expect(subject).to eq 0
    end
  end
  describe '#call' do
    subject { moment.call }
    it 'should call the underlying block' do
      expect(block).to receive(:call).with no_args
      subject
    end
  end
  describe '#enum' do
    let(:distribution) { double }
    let(:opts) { double }
    subject { moment.enum distribution, opts }
    context 'with opts' do
      it 'should create a new MomentEnumerator with opts included' do
        expect(Dodo::MomentEnumerator).to receive(:new).with(moment, distribution, opts)
        subject
      end
    end
    context 'without opts' do
      subject { moment.enum distribution }
      it 'should create a new MomentEnumerator with an empty ahs as opts' do
        expect(Dodo::MomentEnumerator).to receive(:new).with(moment, distribution, {})
        subject
      end
    end
  end
end
Dodo.starting 3.weeks.ago do
  over 2.weeks do
    please do
      puts "#{Time.now} Hello"
    end

    please do
      puts "#{Time.now} goodbye"
    end
  end
end
