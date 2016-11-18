defmodule SlackbotCybozulive.Worker do
  use GenServer

  def start_link(user, token) do
    GenServer.start_link(__MODULE__, [user, token])
  end

  def init([user, token]) do
    send(self, :start)
    {:ok, {user, token}}
  end

  def handle_info(:start, {user, {token, secret}}=state) do
    # TODO: start connection
    {:noreply, state}
  end

end
