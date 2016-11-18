defmodule SlackbotCybozulive do
  use GenServer
  use SlackBot.Plugin

  require Logger

  alias SlackbotCybozulive.AuthServer

  def plugin_init(_team_state) do
    Logger.debug "CybozuLive Plugin init"

    IO.inspect :application.ensure_all_started(:slackbot_cybozulive)

    {:ok, sup} = SlackbotCybozulive.Supervisor.start_link()

    {:ok, sup, [:cyb]}
  end

  def dispatch_command(_sup, :cyb, args, msg) do
    Logger.debug "cybozulive dispatch_command: #{args}"
    case Regex.named_captures(~r/ *(?<subcmd>\w+)( +(?<arg>.*))?/, args) do
      %{"subcmd" => "enable"} ->
        AuthServer.start_auth(msg["user"])
      %{"subcmd" => "verifier", "arg" => arg} ->
        AuthServer.receive_verifier(String.strip(arg), msg["user"])
      _ ->
        Logger.debug "Unknown command #{args}"
    end
  end

end
