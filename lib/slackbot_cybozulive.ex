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
    SlackbotCybozulive.Server.dispatch_command(args, msg)
  end

end
