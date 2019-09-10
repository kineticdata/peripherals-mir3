# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class Mir3NotificationReportRetrieveV1
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

    username = @info_values['username']
    password = @info_values['password']
    notification_id = @parameters['notification_id']
    response = client.request(:get_notification_reports_op) do
      soap.body = {
        :api_version => "4.14",
        :authorization => {
          :username => username,
          :password => password
        },
        :notificationReportUUID => notification_id
      }
    end

    result = response.body[:response][:get_notification_reports_response][:notification_report]

    puts result[:response_options]

    return <<-RESULTS
<results>
  <result name="Id">#{escape(result[:notification_report_uuid])}</result>
  <result name="Title">#{escape(result[:title])}</result>
  <result name="Message">#{escape(result[:verbiage][:text])}</result>
  <result name="Type">#{escape(result[:type])}</result>
  <result name="Time Sent">#{escape(result[:time_sent])}</result>
  <result name="Time Closed">#{escape(result[:time_closed])}</result>
  <result name="Priority">#{escape(result[:priority])}</result>
  <result name="Status">#{escape(result[:status])}</result>
  <result name="Contact Attempts">#{escape(result[:contact_attempts])}</result>
  <result name="Leave Message">#{escape(result[:leave_message])}</result>
  <result name="Paused">#{escape(result[:paused].to_s)}</result>
  <result name="Closed Cause">#{escape(result[:closed_cause])}</result>
  <result name="Initiator Name">#{escape(result[:initiator][:first_name])} #{escape(result[:initiator][:last_name])}</result>
  <result name="Initiator User Id">#{escape(result[:initiator][:user_uuid])}</result>
  <result name="Initiator Username">#{escape(result[:initiator][:username])}</result>
  <result name="Total Response Count">#{escape(result[:general_statistics][:total_response_count])}</result>
  <result name="Total Recipient Count">#{escape(result[:general_statistics][:total_recipient_count])}</result>
  <result name="Total Contacted Count">#{escape(result[:general_statistics][:total_contacted_count])}</result>
  <result name="Total Devices Contacted">#{escape(result[:general_statistics][:total_devices_contacted])}</result>
  <result name="Total Phone Seconds">#{escape(result[:general_statistics][:total_phone_seconds])}</result>
  <result name="Response Options JSON">#{escape(result[:response_options].to_json)}</result>
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