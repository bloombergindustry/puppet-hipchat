require 'puppet'
require 'yaml'

begin
  require 'hipchat'
rescue LoadError
  Puppet.info "You need the `hipchat` gem to use the Hipchat report"
end

Puppet::Reports.register_report(:hipchat) do

  configfile = File.join([File.dirname(Puppet.settings[:config]), "hipchat.yaml"])
  raise(Puppet::ParseError, "Hipchat report config file #{configfile} not readable") unless File.exist?(configfile)
  config = YAML.load_file(configfile)

  HIPCHAT_API = config[:hipchat_api]
  HIPCHAT_ROOM = config[:hipchat_room]
  HIPCHAT_NOTIFY = config[:hipchat_notify]
  HIPCHAT_STATUSES = Array(config[:hipchat_statuses] || 'failed')
  HIPCHAT_PUPPETBOARD = config[:hipchat_puppetboard]
  HIPCHAT_DASHBOARD = config[:hipchat_dashboard]
  HIPCHAT_MAX_MESSAGE_LENGTH = config[:hipchat_max_message_length] || 5000
  HIPCHAT_EXCLUDE = Array(config[:hipchat_exclude] || 'NONE')

  # According to https://www.hipchat.com/docs/api/method/rooms/message
  if HIPCHAT_MAX_MESSAGE_LENGTH > 10000
    HIPCHAT_MAX_MESSAGE_LENGTH = 10000
  end

  # set the default colors if not defined in the config
  HIPCHAT_FAILED_COLOR = config[:failed_color] || 'red'
  HIPCHAT_CHANGED_COLOR = config[:successful_color] || 'green'
  HIPCHAT_UNCHANGED_COLOR = config[:unchanged_color] || 'gray'

  DISABLED_FILE = File.join([File.dirname(Puppet.settings[:config]), 'hipchat_disabled'])
  HIPCHAT_PROXY = config[:hipchat_proxy]

  if HIPCHAT_PROXY && (RUBY_VERSION < '1.9.3' || Gem.loaded_specs["hipchat"].version < '1.0.0')
    raise(Puppet::SettingsError, "hipchat_proxy requires ruby >= 1.9.3 and hipchat gem >= 1.0.0")
  end

  desc <<-DESC
  Send notification of puppet runs to a Hipchat room.
  DESC

  def color(status)
    case status
    when 'failed'
      HIPCHAT_FAILED_COLOR
    when 'changed'
      HIPCHAT_CHANGED_COLOR
    when 'unchanged'
      HIPCHAT_UNCHANGED_COLOR
    else
     'yellow'
    end
  end

  def emote(status)
    case status
    when 'failed'
      '(failed)'
    when 'changed'
      '(successful)'
    when 'unchanged'
      '(continue)'
    end
  end

  def truncate(string, length)
    if length.nil? || string.size <= length
      string
    else
      if length > 3
        "#{string[0, length - 3]}..."
      else
        string[0, length]
      end
    end
  end

  def process
    # Disabled check here to ensure it is checked for every report
    disabled = File.exists?(DISABLED_FILE)
    
    # do we have changes to report
    do_report = 0
    
    status = self.status
    status = 'failed' if self.metrics['resources'].values.find_index { |x| x[0] == 'failed_to_restart' && x[2] > 0 }

    if (HIPCHAT_STATUSES.include?(status) || HIPCHAT_STATUSES.include?('all')) && !disabled
      Puppet.debug "Sending status for #{self.host} to Hipchat channel #{HIPCHAT_ROOM}"
      msg = "Puppet run for #{self.host} #{emote(status)} #{status} at #{Time.now.asctime} on #{self.configuration_version} in #{self.environment}"
      if HIPCHAT_PUPPETBOARD != "NONE"
        msg << "\n#{HIPCHAT_PUPPETBOARD}/report/latest/#{self.host}"
      elsif HIPCHAT_DASHBOARD != "NONE"
        msg << "\n#{HIPCHAT_DASHBOARD}/nodes/#{self.host}/view"
      end
        
      if status == 'changed'
        self.resource_statuses.each do |theresource,resource_status|
          if resource_status.change_count > 0
            unless HIPCHAT_EXCLUDE.include?(resource_status.resource_type)
              msg << "\n  Resource: #{resource_status.title}"
              msg << " Type: #{resource_status.resource_type}"
              do_report = 1
            end
          end
        end
      elsif status == 'failed'
        output = []
        self.logs.each do |log|
          output << log
        end
        msg << output.join("\n")
        do_report = 1
      end

      if do_report == 1
        if HIPCHAT_PROXY
          client = HipChat::Client.new(HIPCHAT_API, :http_proxy => HIPCHAT_PROXY)
        else
          client = HipChat::Client.new(HIPCHAT_API)
        end

        client[HIPCHAT_ROOM].send('Puppet',
                                truncate(msg, HIPCHAT_MAX_MESSAGE_LENGTH),
                                :notify => HIPCHAT_NOTIFY,
                                :color => color(status),
                                :message_format => 'text')

      end
    end
  end
end
