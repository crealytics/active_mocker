require 'spec_helper'
require 'active_mocker/mock/records'
require 'active_mocker/mock/exceptions'
require 'active_support/hash_with_indifferent_access'
require 'active_support/core_ext/object/try'

describe ActiveMocker::Mock::Records do

  subject { described_class.new }

  let(:record) { RecordBase.new }

  before do
    class RecordBase

      attr_accessor :id

      def inspect
        { id: id }
      end

    end
  end

  describe '#insert' do

    before do
      subject.insert(record)
    end

    it 'adds to records' do
      expect(subject.to_a).to include(record)
    end

    it 'gets next id' do
      expect(record.id).to eq 1
    end

    it 'validate unique id' do
      new_record    = RecordBase.new
      new_record.id = 1
      expect { subject.insert(new_record) }.to raise_exception(ActiveMocker::Mock::IdError, 'Duplicate ID found for record {:id=>1}')
    end

  end

  describe '#delete' do

    before do
      subject.insert(record)
      subject.delete(record)
    end

    it 'deletes from record array' do
      expect(subject.to_a).to eq []
    end

    it 'raises if record is not in array' do
      expect { described_class.new.delete(record) }.to raise_error(ActiveMocker::Mock::RecordNotFound, 'Record has not been created.')
    end

  end

  describe '#existis?' do

    it 'returns true if has record' do
      subject.insert(record)
      expect(subject.exists?(record)).to eq true
    end

    it "returns false if doesn't have record" do
      expect(subject.exists?(record)).to eq false
    end

  end

  describe '#new_record?' do

    it 'returns false if has record' do
      subject.insert(record)
      expect(subject.new_record?(record)).to eq false
    end

    it "returns true if doesn't have record" do
      expect(subject.new_record?(record)).to eq true
    end

  end

  describe '#persisted?' do

    it 'returns true if has record' do
      subject.insert(record)
      expect(subject.persisted?(record.id)).to eq true
    end

    it "returns true if doesn't have record" do
      expect(subject.persisted?(record.id)).to eq false
    end

  end

  describe '#reset' do

    it 'clears records array and record_index hash' do
      subject.insert(record)
      subject.reset
      expect(subject.send(:records)).to eq([])
    end

  end

end