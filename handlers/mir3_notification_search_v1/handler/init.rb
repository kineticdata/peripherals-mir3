# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class Mir3NotificationSearchV1
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

    query = {}
    ["notification_title","message","response","call_bridge","first_name","last_name","leave_message",
    "validate_recipient","verify_pin","category","priority","severity"].each do |key|

      next if @parameters[key].to_s.empty?
      if query == "category"
        query[:cat_subcat] = {:category => @parameters['category']}
      else
        query[key.to_sym] = @parameters[key]
      end

    end

    if query == {}
      query[:notification_title] = ""
    end

    username = @info_values['username']
    password = @info_values['password']
    notification_id = @parameters['notification_id']
    response = client.request(:search_notifications_op) do
      soap.body = {
        :api_version => "4.14",
        :authorization => {
          :username => username,
          :password => password
        },
        :max_results => "1000",
        :include_detail => true,
        :query => query
      }
    end

    result = response.body[:response][:search_notifications_response]
    notification_details = []
    if !result[:notification_detail].nil?
      result[:notification_detail].is_a?(Hash) ?
        notification_details = [result[:notification_detail]] :
        notification_details = result[:notification_detail]
    end

    return <<-RESULTS
<results>
  <result name="Match Count">#{result[:match_count]}</result>
  <result name="Return Count">#{result[:return_count]}</result>
  <result name="Notification Details JSON">#{escape(notification_details.to_json)}</result>
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