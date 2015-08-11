require 'spec_helper'

describe ProcessKill do
  it 'has a version number' do
    expect(described_class::VERSION).not_to be nil
  end

  it 'has DEFAULT_FLOW' do
    expect(described_class::DEFAULT_FLOW).not_to be nil
  end

  describe ".compile_flow" do
    let(:flow) { [] }
    subject {described_class.compile_flow(flow) }

    context "with array of interval" do
      let(:flow) { [{signal: 'QUIT', interval: [1,2,3]}] }
      it { is_expected.to eq([signal: 'QUIT', intervals: [1,2,3] ])}
    end

    context "with max_retry and single interval" do
      let(:flow) { [{signal: 'QUIT', max_retry: 3, interval: 5}] }
      it { is_expected.to eq([signal: 'QUIT', intervals: [5,5,5] ])}
    end

    context "with an array of interval larger than max_retry" do
      let(:flow) { [{signal: 'QUIT', max_retry: 2, interval: [1,2,3]}] }
      it { is_expected.to eq([signal: 'QUIT', intervals: [1,2] ])}
    end
  end
end
