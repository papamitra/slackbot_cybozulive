defmodule SlackbotCybozulive.AuthServer do

  use GenServer

  require Logger

  alias SlackbotCybozulive.AuthSupervisor
  alias SlackbotCybozulive.Auth

  def start_link(parent) do
    GenServer.start_link(__MODULE__, [parent], name: __MODULE__)
  end

  def start_auth(user) do
    GenServer.cast(__MODULE__, {:start_auth, user})
  end

  def request_verifier(_user) do
    
  end

  # callback function
  def init([parent]) do
    Logger.debug "#{__MODULE__} init"
    self |> send(:start_sup)
    users = :ets.new(:user_auth, [:set, :private])
    {:ok, %{parent: parent, users: users}}
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

  def handle_info(:start_sup, state) do
    AuthSupervisor.start_link()
    {:noreply, state}
  end

  def handle_info({:request_verifier, from_pid, url}, %{users: users} = state) do
    [[user]] = users |> :ets.match({:"$1", {from_pid, :"_"}})

    SlackBot.send_direct_message(verifier_msg(url),user)

    {:noreply, state}
  end


  defp verifier_msg(url) do
    """
    次のURLにアクセスし、認証コードを取得・入力してください
    #{url}

    cyb verifier <認証コード>
    """
  end

end
