require 'puppet/application'
require 'puppet/util/splunk_hec'

# rubocop:disable Style/ClassAndModuleCamelCase
# splunk_hec.rb
class Puppet::Application::Splunk_hec < Puppet::Application
  include Puppet::Util::Splunk_hec

  RUN_HELP = _("Run 'puppet splunk_hec --help' for more details").freeze

  run_mode :master

  # Options for splunk_hec

  option('--sourcetype SOURCETYPE') do |format|
    options[:sourcetype] = format.downcase.to_sym
  end

  option('--pe_metrics')

  option('--saved_report')

  def get_name(servername)
    name = if servername.to_s == '127-0-0-1'
             Puppet[:certname].to_s
           else
             servername
           end
    name.to_s
  end

  def send_pe_metrics(data, sourcetype)
    timestamp = sourcetypetime(data['timestamp'])
    event_template = {
      'time' => timestamp,
      'sourcetype' => sourcetype.to_s,
      'event' => {},
    }
    data['servers'].keys.each do |server|
      name = get_name(server.to_s)
      content = data['servers'][server.to_s]
      content.keys.each do |serv|
        event = event_template.clone
        event['host'] = name
        event['event'] = content[serv.to_s]
        event['event']['pe_service'] = serv.to_s
        Puppet.info "Submitting metrics to Splunk at #{splunk_url}"
        submit_request(event)
      end
    end
  end

  def upload_report(data, _sourcetype)
    submit_request(data)
  end

  def main
    data = JSON.parse(STDIN.read)
    sourcetype = options[:sourcetype].to_s
    send_pe_metrics(data, sourcetype) if options[:pe_metrics]
    upload_report(data, sourcetype) if options[:saved_report]
  end
end
