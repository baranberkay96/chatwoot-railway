# Seeds Captain's LLM settings from Railway variables.
#
# Chatwoot reads CAPTAIN_OPEN_AI_* from the installation config table (Super
# Admin > App Configs > Captain), not from the environment. This script copies
# the variables into that table only when the setting is still empty, so values
# later changed in the Super Admin UI are never overwritten.
CAPTAIN_KEYS = %w[CAPTAIN_OPEN_AI_API_KEY CAPTAIN_OPEN_AI_ENDPOINT CAPTAIN_OPEN_AI_MODEL].freeze

CAPTAIN_KEYS.each do |name|
  value = ENV.fetch(name, '').strip
  next if value.empty?

  config = InstallationConfig.find_or_initialize_by(name: name)
  if config.value.present?
    puts "[railway] #{name} already configured; leaving it unchanged"
    next
  end

  config.value = value
  config.locked = false if config.new_record?
  config.save!
  puts "[railway] #{name} seeded from environment"
end
