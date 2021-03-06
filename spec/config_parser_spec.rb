require 'spec_helper'

describe Makara::ConfigParser do

  let(:config){
    {
      :top_level => 'value',
      :makara => {
        :connections => [
          {
            :role => 'master',
            :name => 'themaster'
          },
          {
            :name => 'slave1'
          },
          {
            :name => 'slave2'
          }
        ]
      }
    }
  }

  context '::merge_and_resolve_default_url_config' do
    let(:config_without_url) do
      {
        :master_ttl => 5,
        :blacklist_duration => 30,
        :sticky => true,
        :adapter => 'mysql2_makara',
        :encoding => 'utf8',
        :host => 'localhost',
        :database => 'db_name',
        :username => 'db_username',
        :password => 'db_password',
        :port =>     3306
      }
    end

    let(:config_with_url) do
      {
        :master_ttl => 5,
        :blacklist_duration => 30,
        :sticky => true,
        :adapter => 'mysql2_makara',
        :encoding => 'utf8',
        :url => 'mysql2://db_username:db_password@localhost:3306/db_name'
      }
    end

    it 'does nothing to a config without a url parameter' do
      config = config_without_url.dup
      expected = config_without_url.dup
      actual = described_class.merge_and_resolve_default_url_config(config)
      expect(actual).to eq(expected)
    end

    it 'parses the url parameter and merges it into the config' do
      config = config_with_url.dup
      expected = config_without_url.dup
      actual = described_class.merge_and_resolve_default_url_config(config)
      expect(actual).to eq(expected)
    end

    it 'does not use DATABASE_URL env variable' do
      database_url = ENV['DATABASE_URL']
      ENV['DATABASE_URL'] = config_with_url[:url]
      begin
        config = config_with_url.dup
        config.delete(:url)
        expected = config.dup
        actual = described_class.merge_and_resolve_default_url_config(config)
        expect(actual).to eq(expected)
      ensure
        ENV['DATABASE_URL'] = database_url
      end
    end

  end

  it 'should provide a default proxy id based on the recursively sorted config' do
    parsera = described_class.new(config)
    parserb = described_class.new(config.merge(:other => 'value'))
    parserc = described_class.new(config)

    expect(parsera.id).not_to eq(parserb.id)
    expect(parsera.id).to eq(parserc.id)
  end

  it 'should use provided proxy id instead of default' do
    config_with_custom_id = config.dup
    config_with_custom_id[:makara][:id] = 'my_proxy'

    parser = described_class.new(config_with_custom_id)

    expect(parser.id).to eq('my_proxy')
  end

  it 'should replace reserved characters and show a warning for provided proxy ids' do
    config_with_custom_id = config.dup
    config_with_custom_id[:makara][:id] = "my|proxy|id:with:reserved:characters"
    warning = "Proxy id 'my|proxy|id:with:reserved:characters' changed to 'myproxyidwithreservedcharacters'"
    expect(Makara::Logging::Logger).to receive(:log).with(warning, :warn)

    parser = described_class.new(config_with_custom_id)

    expect(parser.id).to eq('myproxyidwithreservedcharacters')
  end

  context 'master and slave configs' do
    it 'should provide master and slave configs' do
      parser = described_class.new(config)
      expect(parser.master_configs).to eq([
        {
          :name => 'themaster',
          :top_level => 'value',
          :sticky => true,
          :blacklist_duration => 30,
          :master_ttl => 5
        }
      ])
      expect(parser.slave_configs).to eq([
        {
          :name => 'slave1',
          :top_level => 'value',
          :sticky => true,
          :blacklist_duration => 30,
          :master_ttl => 5
        },
        {
          :name => 'slave2',
          :top_level => 'value',
          :sticky => true,
          :blacklist_duration => 30,
          :master_ttl => 5
        }
      ])
    end

    it 'connection configuration should override makara config' do
      config[:makara][:blacklist_duration] = 123
      config[:makara][:connections][0][:blacklist_duration] = 456
      config[:makara][:connections][1][:top_level] = 'slave value'

      parser = described_class.new(config)
      expect(parser.master_configs).to eq([
        {
          :name => 'themaster',
          :top_level => 'value',
          :sticky => true,
          :blacklist_duration => 456,
          :master_ttl => 5
        }
      ])
      expect(parser.slave_configs).to eq([
        {
          :name => 'slave1',
          :top_level => 'slave value',
          :sticky => true,
          :blacklist_duration => 123,
          :master_ttl => 5
        },
        {
          :name => 'slave2',
          :top_level => 'value',
          :sticky => true,
          :blacklist_duration => 123,
          :master_ttl => 5
        }
      ])
    end
  end
end
