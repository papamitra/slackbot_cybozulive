defmodule SlackbotCybozulive.Server do
  use GenServer

  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def register_token(user, {_, _} = token) do
    GenServer.cast(__MODULE__, {:register_token, user, token})
  end

  def init([]) do
    {:ok, tokens} = :dets.open_file(:tokens, [type: :set])
    users = :ets.new(:worker_users, [:set, :private])
    send(self, :start_workers)
    {:ok, %{tokens: tokens, users: users}}
  end

  def handle_cast({:register_token, user, token}, %{tokens: tokens, users: users} = state) do
    case :dets.insert_new(tokens, {user, token}) do
      true ->
        start_worker(user, token, users)
      false ->
        # TODO: restart worker?
        Logger.debug "not implemented auth override"
    end

    {:noreply, state}
  end

  def handle_info(:start_workers, %{tokens: tokens, users: users} = state) do
    :dets.foldl(fn {user, token}, _ ->
      start_worker(user, token, users)
    end, nil, tokens)

    {:noreply, state}
  end

  defp start_worker(user, token, users) do
    case Supervisor.start_child(SlackbotCybozulive.WorkerSupervisor, [user, token]) do
      {:ok, child} ->
        ref = Process.monitor(child)
        :ets.insert_new(users, {user, {child, ref, token}})
      _ ->
        Logger.warn "failed to start worker for #{inspect user}"
    end
  end

end
