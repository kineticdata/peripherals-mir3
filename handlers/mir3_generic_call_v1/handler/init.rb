# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class Mir3GenericCallV1
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

    client = Savon.client(endpoint: @info_values['endpoint'], namespace: 'http://www.mir3.com/ws')

    username = @info_values['username']
    password = @info_values['password']
    xml = @parameters['xml']
    error_handling = @parameters['error_handling']
    error_message = nil
    
    begin
      envelope = REXML::Document.new(
        '<?xml version="1.0" encoding="UTF-8"?>
        <env:Envelope 
          xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
          xmlns:tns="http://www.mir3.com/ws" 
          xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" 
          xmlns:ins0="http://www.mir3.com/ws">
          
          <env:Body></env:Body>
        </env:Envelope>'
      )

      doc = REXML::Document.new(xml)
      root = doc.root()
      auth = REXML::Element.new('authorization')
      user = REXML::Element.new('username').add_text(REXML::Text.new(username))
      pass = REXML::Element.new('password').add_text(REXML::Text.new(password))
      auth.add_element(user)
      auth.add_element(pass)
      root.elements["apiVersion"].next_sibling = auth

      root.name = "tns:#{root.name}"
    
      root = addPrefix(root)
      body = ''
      root.each_element do | ele |
        body += ele.to_s
      end

      envelope.elements["env:Envelope"].elements["env:Body"].add_element(root)

      puts "The request envelope: #{envelope}" if @enable_debug_logging

      response = client.call(@parameters["action"].to_sym, xml: envelope.to_s)
      
      result = @parameters["output_type"] == "JSON" ? 
        response.body[:response].to_json : response.to_xml

    rescue Exception => error
      error_message = error.inspect
      raise error if error_handling == "Rasie Error"
    end

    puts "The result of the API call #{result}" if @enable_debug_logging

    results = {} if results.nil?

    return <<-RESULTS
    <results>
      <result name="Handler Error Message">#{escape(error_message)}</result>
      <result name="output">#{escape(result)}</result>     
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

  # Recursive add prefix to xml structure
  def addPrefix(root)
    root.each_element do | ele |
      ele.name = "tns:#{ele.name}"
      if ele.has_elements?
        addPrefix(ele)
      end
    end

    return root
  end

end