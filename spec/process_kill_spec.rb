require 'spec_helper'

describe ProcessKill do
  before do
    allow(described_class).to receive_messages(kill: true, sleep: true)
  end

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

    context "with max_retry and without interval" do
      let(:flow) { [{signal: 'QUIT', max_retry: 4}] }
      it { is_expected.to eq([signal: 'QUIT', intervals: [1,1,1,1] ])}
    end

    context "with max_retry and single interval" do
      let(:flow) { [{signal: 'QUIT', max_retry: 3, interval: 5}] }
      it { is_expected.to eq([signal: 'QUIT', intervals: [5,5,5] ])}
    end

    context "with an array of interval larger than max_retry" do
      let(:flow) { [{signal: 'QUIT', max_retry: 2, interval: [1,2,3]}] }
      it { is_expected.to eq([signal: 'QUIT', intervals: [1,2] ])}
    end

    context "without max_retry and interval" do
      let(:flow) { [{signal: 'QUIT'}] }
      it { is_expected.to eq([signal: 'QUIT', intervals: [1] ])}
    end
  end

  describe ".generate_result_template" do
    let(:pids) { ['pid'] }
    let(:flow) { described_class::DEFAULT_FLOW }
    subject { described_class.generate_result_template(pids, flow) }
    it { is_expected.to include(*pids) }
  end

  describe ".execute" do
    let(:pids) { ['pid'] }
    let(:flow) { [{ signal: 'TERM', max_retry: 5 }] }
    subject { described_class.execute(pids, flow) }

    it { is_expected.to include(*pids) }

    context "killed the process" do
      before do
        allow(described_class).to receive(:kill).and_raise(ProcessKill::ProcessNotFoundError)
      end

      it { expect(subject[pids.first]).to include({attempts: [1], killed: true, resolved: true, signal: "TERM"})}
    end

    context "failed to kill the process" do
      it { expect(subject[pids.first]).to include({attempts: [1,1,1,1,1], killed: false , resolved: false, signal: "TERM"})}
    end

    context "has no permission to the process" do
      before do
        allow(described_class).to receive(:kill).and_raise(ProcessKill::ProcessPermissionError)
      end

      it { expect(subject[pids.first]).to include({attempts: [1], killed: false , resolved: true, signal: "TERM"})}
    end
  end
end
