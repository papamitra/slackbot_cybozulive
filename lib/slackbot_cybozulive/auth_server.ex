defmodule SlackbotCybozulive.AuthServer do

  use GenServer

  require Logger

  alias SlackbotCybozulive.AuthSupervisor
  alias SlackbotCybozulive.Auth

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_auth(user) do
    Logger.debug "#{__MODULE__} start_auth #{user}"

    GenServer.cast(__MODULE__, {:start_auth, user})
  end

  def receive_verifier(verifier, user) do
    GenServer.cast(__MODULE__, {:receive_verifier, verifier, user})
  end

  # callback function
  def init([]) do
    Logger.debug "#{__MODULE__} init"

    users = :ets.new(:user_auth, [:set, :private])

    {:ok, %{users: users}}
  end

  def handle_cast({:start_auth, user}, %{users: users} = state) do
    case users |> :ets.member(user) do
      true ->
        Logger.warn "auth already started for #{user}"
        {:noreply, state}
      false ->
        key = Application.get_env(:slackbot_cybozulive, :consumer_key)
        secret = Application.get_env(:slackbot_cybozulive, :consumer_secret)

        IO.puts "consumer_key: #{key}"

        case Supervisor.start_child(AuthSupervisor, [self, key, secret]) do
          {:ok, child} ->
            ref = Process.monitor(child)
            Auth.auth_start(child)
            users |> :ets.insert_new({user, {child, ref}})
            {:noreply, state}
        end
    end
  end

  def handle_cast({:receive_verifier, verifier, user}, %{users: users} = state) do
    Logger.debug "#{__MODULE__} receive_verifier"

    case users |> :ets.lookup(user) do
      [{^user, {pid, _ref}}] ->
        Auth.auth_verify(pid, verifier)
      _ ->
        SlackBot.send_direct_message("[Error] invalid auth sequence",user)
    end

    {:noreply, state}
  end

  def handle_info({:request_verifier, from_pid, url}, %{users: users} = state) do
    [[user]] = users |> :ets.match({:"$1", {from_pid, :"_"}})

    SlackBot.send_direct_message(verifier_msg(url),user)

    {:noreply, state}
  end

  def handle_info({:auth_completed, from_pid, token, token_secret}, %{users: users} = state) do
    Logger.debug "#{__MODULE__} auth_completed"

    [[user]] = users |> :ets.match({:"$1", {from_pid, :"_"}})

    SlackbotCybozulive.Server.register_token(user, {token, token_secret})
    {:noreply, state}
  end

  # private function

  defp verifier_msg(url) do
    """
    次のURLにアクセスし、認証コードを取得・入力してください
    #{url}

    認証コード入力コマンド: cyb verifier <認証コード>
    """
  end

end
