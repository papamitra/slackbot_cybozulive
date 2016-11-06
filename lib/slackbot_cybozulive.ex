defmodule SlackbotCybozulive do
  use GenServer
  use SlackBot.Plugin

  require Logger

  alias SlackbotCybozulive.AuthServer

  def plugin_init(team_state) do
    Logger.debug "CybozuLive Plugin init"

    Logger.debug "get_all_env: #{inspect Application.get_all_env(:slackbot_cybozulive)}"

    IO.inspect :application.ensure_all_started(:slackbot_cybozulive)

    {:ok, pid} = GenServer.start_link(__MODULE__, [team_state])
    {:ok, pid, [:cyb]}
  end

  def init([team_state]) do
    self |> send(:start_auth_server)

    {:ok, %{team_state: team_state}}
  end

  def dispatch_command(pid, :cyb, args, msg) do
    Logger.debug "cybozulive dispatch_command: #{args}"
    case Regex.named_captures(~r/ *(?<subcmd>\w+)( +(?<arg>.*))?/, args) do
      %{"subcmd" => "enable"} ->
        GenServer.cast(pid, {:enable, msg["user"]})
    end

  end

  def handle_cast({:enable, user}, state) do
    AuthServer.start_auth(user)
    {:noreply, state}
  end

  def handle_info(:start_auth_server, state) do
    AuthServer.start_link(self)

    {:noreply, state}
  end

end
