defmodule SlackbotCybozulive.Worker do
  use GenServer

  require Logger

  alias SlackbotCybozulive.Api

  def start_link(user, token) do
    GenServer.start_link(__MODULE__, [user, token])
  end

  def init([user, {token, token_secret}]) do
    Logger.debug "#{__MODULE__} init"

    key = Application.get_env(:slackbot_cybozulive, :consumer_key)
    secret = Application.get_env(:slackbot_cybozulive, :consumer_secret)
    creds = OAuther.credentials(consumer_key: key,
      consumer_secret: secret, token: token, token_secret: token_secret)

    IO.inspect creds

    send(self, :start)

    {:ok, %{user: user, creds: creds}}
  end

  def handle_info(:start, %{creds: creds} = state) do
    Logger.debug "#{__MODULE__} start"

    {:noreply, state}
  end

end
