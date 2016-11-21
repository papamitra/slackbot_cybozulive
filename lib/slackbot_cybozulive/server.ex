defmodule SlackbotCybozulive.Server do
  use GenServer

  require Logger

  @slackbot Application.get_env(:slackbot_cybozulive, :slackbot)

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def register_token(user, {_, _} = token) do
    GenServer.cast(__MODULE__, {:register_token, user, token})
  end

  def dispatch_command(args, msg) do
    GenServer.cast(__MODULE__, {:dispatch_command, args, msg})
  end

  def init([]) do
    {:ok, tokens} = :dets.open_file(:tokens, [type: :set])
    users = :ets.new(:worker_users, [:set, :private])
    send(self, :start_workers)
    {:ok, %{tokens: tokens, users: users}}
  end

  def handle_cast({:register_token, user, token}, %{tokens: tokens, users: users} = state) do
    case tokens |> :dets.insert_new({user, token}) do
      true ->
        Logger.debug "#{__MODULE__} register_token #{user} #{inspect token}"

        start_worker(user, token, users)
      false ->
        # TODO: restart worker?
        Logger.debug "not implemented auth override"
    end

    {:noreply, state}
  end

  def handle_cast({:dispatch_command, args, msg}, %{users: users, tokens: tokens} = state) do
    case Regex.named_captures(~r/ *(?<subcmd>\w+)( +(?<arg>.*))?/, args) do
      %{"subcmd" => "enable"} ->
        subcommand_enable(msg, users)
      %{"subcmd" => "verifier", "arg" => arg} ->
        subcommand_verifier(arg, msg)
      %{"subcmd" => "disable"} ->
        subcommand_disable(msg, users, tokens)
      %{"subcmd" => "schedule"} ->
        subcommand_schedule(msg, users)
      _ ->
        Logger.debug "Unknown command #{args}"
    end

    {:noreply, state}
  end

  def handle_info(:start_workers, %{tokens: tokens, users: users} = state) do
    :dets.foldl(fn {user, token}, _ ->
      start_worker(user, token, users)
    end, nil, tokens)

    {:noreply, state}
  end

  # private function

  defp start_worker(user, token, users) do
    case Supervisor.start_child(SlackbotCybozulive.WorkerSupervisor, [user, token]) do
      {:ok, child} ->
        ref = Process.monitor(child)
        :ets.insert_new(users, {user, {child, ref, token}})
      _ ->
        Logger.warn "failed to start worker for #{inspect user}"
    end
  end

  defp subcommand_enable(msg, users) do
    case users |> :ets.lookup(msg["user"]) do
      [{user, _}] ->
        @slackbot.send_direct_message("[Warning] CybozuLive plugin already enabled.", user)
      _ ->
        SlackbotCybozulive.AuthServer.start_auth(msg["user"])
    end
  end

  defp subcommand_verifier(arg, msg) do
    SlackbotCybozulive.AuthServer.receive_verifier(String.strip(arg), msg["user"])
  end

  defp subcommand_disable(msg, users, tokens) do
    user = msg["user"]

    tokens |> :dets.delete(user)

    case users |> :ets.lookup(user) do
      [{user, {child, ref, _}}] ->
        Logger.debug "#{__MODULE__} disable user: #{user}"

        Process.demonitor(ref)
        Supervisor.terminate_child(SlackbotCybozulive.WorkerSupervisor, child)
        users |> :ets.delete(user)
      _ ->
        :ok
    end
  end

  defp subcommand_schedule(msg, users) do
    [{_user, {child, _, _}}] = users |> :ets.lookup(msg["user"])
    SlackbotCybozulive.Worker.cmd_schedule(child)
  end

end
