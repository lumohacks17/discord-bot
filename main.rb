require 'discordrb'
require 'pry'
require 'json'
require 'fuzzystringmatch'
require_relative 'services/discord_message_sender'

class Main
  ERROR_COLOR = "E74C3C"
  SUCCESS_COLOR = "1ABC9C"

  secrets = JSON.parse(File.read('secrets.json'))

  bot = Discordrb::Commands::CommandBot.new(
    token: "wNWY7vmZFsqPwoaPB9rRY0mbx-NXQd5",
    client_id: 499819124378304512,
    prefix: '~',
  )

  puts "This bot's invite URL is #{bot.invite_url}."
  puts 'Click on it to invite it to your server.'

  $commands = {
    "~purge <2-99>" => "remove the last `n` messages in channel (**admin only**)",
    "~help" => "return the help menu"
  }

  $role_commands = {
    "~status add <status>" => "add your interview status to your profile (interviewing, summer2019, fall2019, winter2019, matched, other)",
    "~location add <location>" => "add your office to your profile (newyork, mountainview, seattle, etc.)",
  }

  bot.ready() do |event|
    bot.game="~help"
  end

  bot.command(:help) do |event|
    begin
      event.message.delete
    rescue Discordrb::Errors::NoPermission
      DiscordMessageSender.send_embedded(
        event.user.pm,
        title: "Error",
        description: ":bangbang: Bot has insufficient permissions to delete your command message.",
      )
    end

    fields = []
    fields << Discordrb::Webhooks::EmbedField.new(
      name: "General Commands",
      value: $commands.each_with_object("") do |(command, description), commands_string|
        commands_string << "**`#{command}`** - #{description}\n"
      end + "\n\u200B"
    )

    fields << Discordrb::Webhooks::EmbedField.new(
      name: "Role Commands",
      value: $role_commands.each_with_object("") do |(command, description), commands_string|
        commands_string << "**`#{command}`** - #{description}\n"
      end + "\n\u200B"
    )

    DiscordMessageSender.send_embedded(
      event.user.pm,
      title: "Help Menu",
      description: "Note: Arguments in <this format> do not require the '<', '>' characters\n\u200B",
      fields: fields,
    )
  end

  bot.command(:purge) do |event|
    return if event.server.nil?
    num_messages = event.message.content.split(' ').drop(1).join(' ').to_i + 1
    member = event.server.members.find { |member| member.id == event.user.id }

    if member.permission?(:administrator) || member.roles.find { |role| role.name == "Mod" }
      if num_messages < 2 || num_messages > 100
        DiscordMessageSender.send_embedded(
          member.pm,
          title: "Invalid Usage",
          description: ":bangbang: Invalid number of messages to be removed.\n\n Correct usage: `~purge <2-99>`",
          color: ERROR_COLOR,
        )
        return
      end
      event.channel.prune(num_messages)
    else
      DiscordMessageSender.send_embedded(
        member.pm,
        title: "Insufficient Permissions",
        description: ":bangbang: You do not have permission to use this command.",
        color: ERROR_COLOR,
      )
      event.message.delete
    end 
  end

  bot.command(:status) do |event|
    begin
      event.message.delete
    rescue Discordrb::Errors::NoPermission
      DiscordMessageSender.send_embedded(
        event.user.pm,
        title: "Error",
        description: ":bangbang: Bot has insufficient permissions to delete your command message.",
      )
    end

    role_requested = event.message.content.split(' ')[2].upcase

    if event.server.nil?
      DiscordMessageSender.send_embedded(
        event.user.pm,
        title: "Invalid Usage",
        description: ":bangbang: Please use this command in the server.",
        color: ERROR_COLOR,
      )
      return
    end

    server = event.server
    member = server.members.find { |member| member.id == event.user.id }

    roles = {
      "WINTER2019" => server.roles.find { |role| role.name == "Winter 2019"},
      "SUMMER2019" => server.roles.find { |role| role.name == "Summer 2019"},
      "FALL2019" => server.roles.find { |role| role.name == "Fall 2019"},
      "INTERVIEWING" => server.roles.find { |role| role.name == "Interviewing"},
      "MATCHED" => server.roles.find { |role| role.name == "Matched"},
      "OTHER" => server.roles.find { |role| role.name == "Other"},
    }

    if !(roles.include? role_requested)
      DiscordMessageSender.send_embedded(
        member.pm,
        title: "Invalid Usage",
        description: ":bangbang: Invalid option. Please select from: `#{roles.keys.to_s}`",
        color: ERROR_COLOR,
      )
      return
    end

    role_to_add = roles[role_requested]

    if role_to_add
      begin
        member.add_role(role_to_add)
        if role_to_add.name == "Matched"
          general_channel = event.server.channels.find { |channel| channel.name == "general" }
          unless general_channel.nil?
            DiscordMessageSender.send_embedded(
              server.channels.find { |channel| channel.name == "general" },
              title: "Congratulations!!",
              description: ":tada: :tada: Congratulations to #{member.name} for matching with a team!",
              color: SUCCESS_COLOR,
            )
          end
        else
          previous_roles = member.roles.select { |role| (roles.values.include? role) && role != role_to_add && role.name != "Matched" }
          previous_roles.each { |role| member.remove_role(role) }
        end
        DiscordMessageSender.send_embedded(
          member.pm,
          title: "Success",
          description: ":white_check_mark: The role was added to your profile.",
          color: SUCCESS_COLOR,
        )
      rescue Discordrb::Errors::NoPermission
        DiscordMessageSender.send_embedded(
          member.pm,
          title: "Error",
          description: ":bangbang: Bot has insufficient permissions to modify your roles. This may be because you're an admin. If not, contact the admin about this issue.",
          color: ERROR_COLOR,
        )
      end
    else
      DiscordMessageSender.send_embedded(
        member.pm,
        title: "Error",
        description: ":bangbang: Bot was unable to find the associating role in the server. Please notify admin.",
        color: ERROR_COLOR,
      )
    end
  end

  bot.command(:location) do |event|
    begin
      event.message.delete
    rescue Discordrb::Errors::NoPermission
      DiscordMessageSender.send_embedded(
        event.user.pm,
        title: "Error",
        description: ":bangbang: Bot has insufficient permissions to delete your command message.",
      )
    end

    location_requested = event.message.content.split(' ')[2].upcase

    if event.server.nil?
      DiscordMessageSender.send_embedded(
        event.user.pm,
        title: "Invalid Usage",
        description: ":bangbang: Please use this command in the server.",
        color: ERROR_COLOR,
      )
      return
    end

    server = event.server
    member = server.members.find { |member| member.id == event.user.id }

    locations = {
      "MOUNTAINVIEW" => server.roles.find { |role| role.name == "Mountain View"},
      "SUNNYVALE" => server.roles.find { |role| role.name == "Sunnyvale"},
      "SAN BRUNO" => server.roles.find { |role| role.name == "San Bruno"},
      "IRVINE" => server.roles.find { |role| role.name == "Irvine"},
      "LOS ANGELES" => server.roles.find { |role| role.name == "Los Angeles"},
      "BOULDER" => server.roles.find { |role| role.name == "Boulder"},
      "CHICAGO" => server.roles.find { |role| role.name == "Chicago"},
      "CAMBRIDGE" => server.roles.find { |role| role.name == "Cambridge"},
      "CHAPELHILL" => server.roles.find { |role| role.name == "Chapel Hill"},
      "NEWYORK" => server.roles.find { |role| role.name == "New York"},
      "WATERLOO" => server.roles.find { |role| role.name == "Waterloo"},
      "PITTSBURGH" => server.roles.find { |role| role.name == "Pittsburgh"},
      "MONTREAL" => server.roles.find { |role| role.name == "Montreal"},
      "SEATTLE" => server.roles.find { |role| role.name == "Seattle"},
      "MADISON" => server.roles.find { |role| role.name == "Madison"},
    }

    if !(locations.include? location_requested)
      DiscordMessageSender.send_embedded(
        member.pm,
        title: "Invalid Usage",
        description: ":bangbang: Invalid option. Please select from: `#{locations.keys.to_s}`",
        color: ERROR_COLOR,
      )
      return
    end

    location_to_add = locations[location_requested]

    if location_to_add
      begin
        member.add_role(location_to_add)
        if location_to_add.name == "Matched"
          general_channel = event.server.channels.find { |channel| channel.name == "general" }
          unless general_channel.nil?
            DiscordMessageSender.send_embedded(
              server.channels.find { |channel| channel.name == "general" },
              title: "Congratulations!!",
              description: ":tada: :tada: Congratulations to #{member.name} for matching with a team!",
              color: SUCCESS_COLOR,
            )
          end
        else
          previous_locations = member.roles.select { |role| (locations.values.include? role) && role != location_to_add }
          previous_locations.each { |role| member.remove_role(role) }
        end
        DiscordMessageSender.send_embedded(
          member.pm,
          title: "Success",
          description: ":white_check_mark: The location was added to your profile.",
          color: SUCCESS_COLOR,
        )
      rescue Discordrb::Errors::NoPermission
        DiscordMessageSender.send_embedded(
          member.pm,
          title: "Error",
          description: ":bangbang: Bot has insufficient permissions to modify your locations. This may be because you're an admin. If not, contact the admin about this issue.",
          color: ERROR_COLOR,
        )
      end
    else
      DiscordMessageSender.send_embedded(
        member.pm,
        title: "Error",
        description: ":bangbang: Bot was unable to find the associating location in the server. Please notify admin.",
        color: ERROR_COLOR,
      )
    end
  end

  bot.run
end
