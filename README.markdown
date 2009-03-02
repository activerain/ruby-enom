eNom domain reseller API wrapper
================================

Based on documentation found in:
http://resellertest.enom.com/resellers/newdocumentation.asp

Example
-------

    require 'ruby-enom'

    # Configure RubyEnom with your company's specifics
    RubyEnom::COMMANDS_DEFAULT_OPTIONS.merge!({
      :purchase => {
        :NS1                        => 'ns1.example.com',
        :NS2                        => 'ns2.example.com',
        :NumYears                   => 2,
        :RegistrantOrganizationName => 'Example Corp.',
        :RegistrantAddress1         => 'Your address',
        :RegistrantCity             => 'City name',
        :RegistrantPostalCode       => 93000,
        :RegistrantCountry          => 'US',
        :RegistrantEmailAddress     => 'youremail@example.com',
        :RegistrantPhone            => '555',
        :RegistrantFax              => '555'
      }
    })

    enom = RubyEnom::Connection.new('username', 'password', 'http://resellertest.enom.com/interface.asp')
    if enom.domain_available?("example.com")
      resp = enom.purchase(:sld => "example", :tld => "com")
      if resp.has_errors?
        puts "Errors while trying to purchase domain 'example.com': #{resp.errors.join(', ')}"
      end
    end

Check the source and eNom's documentation on commands. This wrapper is easily extensible.
