# frozen_string_literal: true

require 'active_support/core_ext/numeric/time'

RSpec.describe Dodo::Container do
  let(:duration) { 2.weeks }
  let(:block) { proc { true } }
  let(:container) { described_class.new }
  let(:serial_duration) { 1.week }
  let(:serial) { Dodo::SerialTimeline.new serial_duration, &block }
  let(:offset) { 3.days }
  let(:offset_serial) { Dodo::OffsetTimeline.new serial, offset }

  describe '#initialize' do
    subject { container }

    context 'without a block' do
      it 'should have an initial duration of 0' do
        expect(subject.duration).to eq 0
      end
    end

    context 'with a block' do
      let(:allocated) { Dodo::Container.allocate }
      let(:block) { proc { true } }

      subject { Dodo::Container.new(&block) }

      it 'should have an initial duration of 0' do
        expect(subject.duration).to eq 0
      end

      it 'should call instance_eval using the block passed' do
        expect(allocated).to receive(:instance_eval) do |&blk|
          expect(blk).to eq block
        end
        allocated.send :initialize, &block
      end
    end
  end

  shared_examples 'an appender of timelines' do
    it 'should append to the timelines array' do
      expect { subject }.to change { container.to_a.size }.by 1
    end

    it 'should append the serial provided to the timelines array' do
      expect(subject.to_a.last).to eq offset_serial
    end

    it 'should return the container itself' do
      expect(subject).to be container
    end
  end

  shared_examples 'a method that allows additional timelines be ' \
                  'added to a container' do
    context 'when passed a single OffsetTimeline as an argument' do
      context 'with a newly initialized container' do
        it_behaves_like 'an appender of timelines'

        it 'should update the container duration to that of the
            appended serial' do
          subject
          expect(
            container.duration
          ).to eq offset_serial.duration + offset_serial.offset
        end
      end

      context 'with the sum of the duration of the appended serial and' \
              'its offset LESS than that of the containers duration' do
        before do
          allow(container).to receive(:duration).and_return(3.weeks)
        end

        it_behaves_like 'an appender of timelines'

        it 'should not change the duration of the container' do
          expect { subject }.not_to(change { container.duration })
        end
      end

      context 'with the sum of the duration of the appended serial and' \
              'its offset GREATER that that of the containers duration' do

        let(:offset) { duration + 1.week }

        it_behaves_like 'an appender of timelines'

        it 'should change the duration of the container to the sum of the ' \
           'appended serial and its offset' do
          expect(subject.duration).to eq(
            offset_serial.duration + offset_serial.offset
          )
        end
      end
    end
  end

  describe '#over' do
    let(:offset) { 0 }
    subject { container.over serial_duration, after: offset, &block }
    before do
      container # Ensure the container is created before patching the
      # serial constructor
      allow(Dodo::SerialTimeline).to receive(:new).and_return(serial)
    end
    it_behaves_like(
      'a method that allows additional timelines be added to a container'
    )
  end

  describe '#also' do
    subject { container.also after: offset, over: serial_duration, &block }

    before do
      container # Ensure the container is created before patching the
      # serial constructor
      allow(Dodo::SerialTimeline).to receive(:new).and_return(serial)
    end

    context 'with an integer provided' do
      it_behaves_like(
        'a method that allows additional timelines be added to a container'
      )
    end
  end

  describe '#use' do
    context 'with a pre-baked serial provided' do
      subject { container.use serial, after: offset }
      it_behaves_like(
        'a method that allows additional timelines be added to a container'
      )
    end

    context 'with many pre-baked timelines provided' do
      let(:timelines) { build_list :serial, 3 }
      let(:offset_timelines) do
        timelines.map { |serial| Dodo::OffsetTimeline.new serial, offset }
      end

      subject { container.use(*timelines, after: offset) }

      it 'should append to the timelines array' do
        expect { subject }.to change {
          container.to_a.size
        }.by timelines.size
      end

      it 'should append the serial provided to the timelines array' do
        expect(subject.to_a.last(timelines.size)).to eq offset_timelines
      end

      it 'should return the container itself' do
        expect(subject).to be container
      end
    end
  end

  describe '#repeat' do
    let(:times) { 3 }
    subject do
      container.repeat(
        times: times, over: serial_duration, after: offset, &block
      )
    end

    before do
      container # Ensure the container is created before patching the
      # serial constructor
      allow(Dodo::SerialTimeline).to receive(:new).and_return(serial)
    end

    it 'should append to the timelines array' do
      expect { subject }.to change { container.to_a.size }.by times
    end

    it 'should append the serial provided to the timelines array' do
      expect(subject.to_a.last(times)).to eq([offset_serial] * 3)
    end

    it 'should return the container itself' do
      expect(subject).to be container
    end
  end

  describe '#scheduler' do
    let(:starting_offset) { 2.days }
    let(:context) { Dodo::Context.new }
    let(:distribution) { starting_offset }
    subject { container.scheduler starting_offset, context }
    context 'without opts' do
      it 'should create and return a new ContainerScheduler' do
        expect(subject).to be_a Dodo::ContainerScheduler
      end
      it 'should create a ContainerScheduler with an empty hash as opts' do
        expect(Dodo::ContainerScheduler).to receive(:new).with(
          container, starting_offset, context, {}
        )
        subject
      end
    end
    context 'with opts' do
      let(:opts) { { stretch: 4 } }
      subject { container.scheduler starting_offset, context, opts }
      it 'should create and return a new ContainerScheduler' do
        expect(subject).to be_a Dodo::ContainerScheduler
      end
      it 'should create a ContainerScheduler with an empty hash as opts' do
        expect(Dodo::ContainerScheduler).to receive(:new).with(
          container, starting_offset, context, opts
        )
        subject
      end
    end
  end
end
