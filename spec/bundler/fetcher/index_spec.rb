# frozen_string_literal: true

RSpec.describe Lic::Fetcher::Index do
  let(:downloader)  { nil }
  let(:remote)      { nil }
  let(:display_uri) { "http://sample_uri.com" }
  let(:rubygems)    { double(:rubygems) }
  let(:gem_names)   { %w[foo bar] }

  subject { described_class.new(downloader, remote, display_uri) }

  before { allow(Lic).to receive(:rubygems).and_return(rubygems) }

  it "fetches and returns the list of remote specs" do
    expect(rubygems).to receive(:fetch_all_remote_specs) { nil }
    subject.specs(gem_names)
  end

  context "error handling" do
    shared_examples_for "the error is properly handled" do
      let(:remote_uri) { URI("http://remote-uri.org") }
      before do
        allow(subject).to receive(:remote_uri).and_return(remote_uri)
      end

      context "when certificate verify failed" do
        let(:error_message) { "certificate verify failed" }

        it "should raise a Lic::Fetcher::CertificateFailureError" do
          expect { subject.specs(gem_names) }.to raise_error(Lic::Fetcher::CertificateFailureError,
            %r{Could not verify the SSL certificate for http://sample_uri.com})
        end
      end

      context "when a 401 response occurs" do
        let(:error_message) { "401" }

        it "should raise a Lic::Fetcher::AuthenticationRequiredError" do
          expect { subject.specs(gem_names) }.to raise_error(Lic::Fetcher::AuthenticationRequiredError,
            %r{Authentication is required for http://remote-uri.org})
        end
      end

      context "when a 403 response occurs" do
        let(:error_message) { "403" }

        before do
          allow(remote_uri).to receive(:userinfo).and_return(userinfo)
        end

        context "and there was userinfo" do
          let(:userinfo) { double(:userinfo) }

          it "should raise a Lic::Fetcher::BadAuthenticationError" do
            expect { subject.specs(gem_names) }.to raise_error(Lic::Fetcher::BadAuthenticationError,
              %r{Bad username or password for http://remote-uri.org})
          end
        end

        context "and there was no userinfo" do
          let(:userinfo) { nil }

          it "should raise a Lic::Fetcher::AuthenticationRequiredError" do
            expect { subject.specs(gem_names) }.to raise_error(Lic::Fetcher::AuthenticationRequiredError,
              %r{Authentication is required for http://remote-uri.org})
          end
        end
      end

      context "any other message is returned" do
        let(:error_message) { "You get an error, you get an error!" }

        before { allow(Lic).to receive(:ui).and_return(double(:trace => nil)) }

        it "should raise a Lic::HTTPError" do
          expect { subject.specs(gem_names) }.to raise_error(Lic::HTTPError, "Could not fetch specs from http://sample_uri.com")
        end
      end
    end

    context "when a Gem::RemoteFetcher::FetchError occurs" do
      before { allow(rubygems).to receive(:fetch_all_remote_specs) { raise Gem::RemoteFetcher::FetchError.new(error_message, nil) } }

      it_behaves_like "the error is properly handled"
    end

    context "when a OpenSSL::SSL::SSLError occurs" do
      before { allow(rubygems).to receive(:fetch_all_remote_specs) { raise OpenSSL::SSL::SSLError.new(error_message) } }

      it_behaves_like "the error is properly handled"
    end

    context "when a Net::HTTPFatalError occurs" do
      before { allow(rubygems).to receive(:fetch_all_remote_specs) { raise Net::HTTPFatalError.new(error_message, 404) } }

      it_behaves_like "the error is properly handled"
    end
  end
end
