# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class Mir3NotificationSendV1
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Store the info values in a Hash of info names to values.
    @info_values = {}
    REXML::XPath.each(@input_document,"/handler/infos/info") { |item|
      @info_values[item.attributes['name']] = item.text
    }

    # Store parameters values in a Hash of parameter names to values.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text.to_s
    end

    @enable_debug_logging = @info_values['enable_debug_logging'].downcase == 'yes' ||
                            @info_values['enable_debug_logging'].downcase == 'true'
    puts "Parameters: #{@parameters.inspect}" if @enable_debug_logging
  end

  def execute()
    puts "Configure Savon logging" if @enable_debug_logging

    # Savon's trace logged is enabled by default. If @enable_debug_logging isn't set, configure
    # the logging back down to a less verbose level.
    Savon.configure do |config|
      config.log = @enable_debug_logging
      config.log_level = @enable_debug_logging ? :debug : :error
      HTTPI.log = @enable_debug_logging
    end

    client = Savon::Client.new do |wsdl,http,wsse|
      wsdl.document = File.expand_path("../resources/inWebServices-4_14.wsdl.xml", __FILE__)
    end

    details = {}
    # Build up the simple notification details
    details[:title] = @parameters['title']
    details[:description] = @parameters['description'] if !@parameters['description'].to_s.empty?
    details[:message] = @parameters['message']
    details[:verbiage] = {:text => @parameters['message']}
    # Build up the response options body if it is present
    if !@parameters['response_options'].to_s.empty?
      r_opts = []
      @parameters['response_options'].to_s.split(',').each do |option|
        r_opts.push({:verbiage => {:text => option.strip}})
      end
      details[:response_options] = {:response_option => r_opts}
    end
    # Build up the recipient array because it will be the same for each notification type
    recipients = []
    @parameters['recipients'].to_s.split(',').each do |recipient|
      recipients.push({:username => recipient.strip})
    end
    # Build the info for the chosen notification method
    if @parameters['method'].to_s == "Broadcast"
      details[:broadcast_info] = {
        :broadcast_duration => (@parameters['broadcast_duration'].to_i * 60).to_s,
        :recipients => {:recipient => recipients}
      }
    elsif @parameters['method'].to_s == "First Response"
      details[:first_response_info] = {
        :escalations => {
          :escalation => [
            {
              :recipient => recipients
            }
          ]
        }
      }
    elsif @parameters['method'].to_s == "Callout"
      details[:callout_info] = {
        :call_out_success_total => @parameters['callout_success_total'],
        :escalations => {
          :escalation => [
            {
              :recipient => recipients
            }
          ]
        }
      }
    elsif @parameters['method'].to_s == "Bulletin Board"
      details[:broadcast_info] = {
        :broadcast_duration => (@parameters['broadcast_duration'].to_i * 60).to_s,
        :recipients => {:recipient => recipients}
      }
    else
      raise "Notification method '#{@parameters['method']}' is not currently supported"
    end

    username = @info_values['username']
    password = @info_values['password']
    notification_id = @parameters['notification_id']
    response = client.request(:one_step_notification_op) do
      soap.body = {
        :api_version => "4.14",
        :authorization => {
          :username => username,
          :password => password
        },
        :notification_detail => details
      }
    end

    return <<-RESULTS
    <results>
      <result name="Id">#{escape(response.body[:response][:one_step_notification_response][:notification_report_uuid])}</result>
    </results>
    RESULTS
  end

  # This is a template method that is used to escape results values (returned in
  # execute) that would cause the XML to be invalid.  This method is not
  # necessary if values do not contain character that have special meaning in
  # XML (&, ", <, and >), however it is a good practice to use it for all return
  # variable results in case the value could include one of those characters in
  # the future.  This method can be copied and reused between handlers.
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}

end