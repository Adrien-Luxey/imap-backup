module Imap::Backup
  describe Serializer::MessageEnumerator do
    subject { described_class.new(imap: imap) }

    let(:imap) { instance_double(Serializer::Imap, get: message) }
    let(:message) { instance_double(Serializer::Message) }
    let(:good_uid) { 999 }

    before do
      allow(imap).to receive(:get) { nil }
      allow(imap).to receive(:get).with(good_uid) { message }
    end

    it "yields messages" do
      expect { |b| subject.run(uids: [good_uid], &b) }.
        to yield_successive_args(message)
    end

    context "with UIDs that are not present" do
      it "skips them" do
        expect { |b| subject.run(uids: [good_uid, 1234], &b) }.
          to yield_successive_args(message)
      end
    end
  end
end
