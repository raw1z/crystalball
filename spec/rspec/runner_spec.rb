# frozen_string_literal: true

require 'spec_helper'

describe Crystalball::RSpec::Runner do
  subject { described_class }

  let(:map) { instance_double('Crystalball::MapStorage::YAMLStorage') }

  before do
    described_class.reset!
    allow(Crystalball::MapStorage::YAMLStorage).to receive(:load).and_return(map)
    allow_any_instance_of(described_class).to receive(:run).and_return 0
  end

  describe '.prepare' do
    let(:expected_config) { {'map_path' => 'map.yml', 'map_expiration_period' => 0} }
    let(:config_content) { expected_config.to_yaml }

    it 'loads predictor map' do
      expect(subject.prepare).to eq map
    end

    it 'performs predictor setup' do
      expect(Crystalball::RSpec::PredictionBuilder).to receive(:new).and_call_original
      subject.prepare
    end

    before { allow(Pathname).to receive(:new).and_call_original }

    context 'with CRYSTALBALL_CONFIG env variable set' do
      let(:expected_config) { YAML.safe_load(Pathname('spec/fixtures/example_runner_config.yml').read) }
      let(:config_file) { double(read: config_content, exist?: true) }
      before do
        allow(Pathname).to receive(:new).with('spec/fixtures/example_runner_config.yml').and_return(config_file)
      end

      around do |example|
        ENV['CRYSTALBALL_CONFIG'] = 'spec/fixtures/example_runner_config.yml'
        example.call
        ENV.delete('CRYSTALBALL_CONFIG')
      end

      specify do
        expect(Crystalball::RSpec::PredictionBuilder)
          .to receive(:new).with(expected_config).and_call_original
        subject.prepare
      end
    end

    context 'if crystalball.yml is present' do
      let(:config_file) { double(read: config_content, exist?: true) }
      before do
        allow(Pathname).to receive(:new).with('crystalball.yml').and_return(config_file)
      end

      specify do
        expect(Crystalball::RSpec::PredictionBuilder).to receive(:new).with(expected_config).and_call_original
        subject.prepare
      end
    end

    context 'if config/crystalball.yml is present' do
      let(:config_file) { double(read: config_content, exist?: true) }
      before do
        allow(Pathname).to receive(:new).with('crystalball.yml').and_return(double(exist?: false))
        allow(Pathname).to receive(:new).with('config/crystalball.yml').and_return(config_file)
      end

      specify do
        expect(Crystalball::RSpec::PredictionBuilder).to receive(:new).with(expected_config).and_call_original
        subject.prepare
      end
    end
  end

  describe '.run' do
    let(:prediction_builder) do
      instance_double('Crystalball::RSpec::PredictionBuilder', prediction: double(compact: compact_prediction), expired_map?: false)
    end
    let(:compact_prediction) { ['test'] }

    before do
      allow(described_class).to receive(:prediction_builder).and_return prediction_builder
    end

    it 'runs rspec with prediction' do
      expect(RSpec::Core::ConfigurationOptions).to receive(:new).with(['test']).and_call_original

      described_class.run([])
    end

    context 'with expired map' do
      before { allow(prediction_builder).to receive(:expired_map?).and_return true }

      let(:out_stream) { double(puts: true) }

      it 'prints out warning' do
        expect(out_stream).to receive(:puts).with('Maps are outdated!')
        described_class.run([], STDERR, out_stream)
      end
    end
  end
end