defmodule SlackbotCybozulive.Worker do
  use GenServer

  require Logger

  alias SlackbotCybozulive.Api

  @slackbot Application.get_env(:slackbot_cybozulive, :slackbot)

  def start_link(user, token) do
    GenServer.start_link(__MODULE__, [user, token])
  end

  def cmd_schedule(pid) do
    GenServer.cast(pid, :schedule)
  end

  def init([user, {token, token_secret}]) do
    Logger.debug "#{__MODULE__} init"

    key = Application.get_env(:slackbot_cybozulive, :consumer_key)
    secret = Application.get_env(:slackbot_cybozulive, :consumer_secret)
    creds = OAuther.credentials(consumer_key: key,
      consumer_secret: secret, token: token, token_secret: token_secret)

    {:ok, %{user: user, creds: creds}}
  end

  def handle_cast(:schedule, %{creds: creds, user: user} = state) do
    {schedules, _} = Api.get_schedule(creds)
    |> Enum.reduce({[], nil}, fn v, {acc, day} ->
      %{title: title, start_time: start_time, end_time: end_time} = v
      begin = Timex.beginning_of_day(start_time)
      {acc, day} =
        if day == begin do
          {acc, day}
        else
          {[Timex.format!(begin, "{YYYY}-{0M}-{0D}") | acc] , begin}
        end

      stime = Timex.format!(start_time, "%0H:%0M", :strftime)
      etime = Timex.format!(end_time, "%0H:%0M", :strftime)

      acc = ["    #{stime} - #{etime} " <> title | acc]
      {acc, day}
    end)

    msg = schedules |> Enum.reverse |> Enum.join("\n")

    @slackbot.send_direct_message(msg, user)

    {:noreply, state}
  end

end
