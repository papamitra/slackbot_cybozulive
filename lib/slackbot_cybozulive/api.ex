defmodule SlackbotCybozulive.Api do
  use Timex

  @connection "https://api.cybozulive.com/api/mpAddress/V2?"
  @schedule "https://api.cybozulive.com/api/schedule/V2?"
  @group "https://api.cybozulive.com/api/group/V2"
  @gwschedule "https://api.cybozulive.com/api/gwSchedule/V2?"

  require Logger

  def get_id(creds, name) do
    {:ok, res} = get(@connection <> URI.encode_query(%{"name" => name}), creds)

    res.body
    |> Quinn.parse
    |> Quinn.find(:"cbl:who")
    |> Enum.reduce([], fn (v,acc) ->
      case v do
        %{attr: [valueString: name, id: id]} ->
          [{id, name} | acc]
        _ ->
          acc
      end
    end)
  end

  def get_group(creds) do
    get(@group, creds)
  end

  def get_gwschedule(creds) do
    group = "X:XXXXXXXXXX"
    IO.inspect get(@gwschedule <> URI.encode_query(%{"group" => group}), creds)
  end

  def get_schedule(creds) do
    get_schedule(creds, today_am5)
  end
  def get_schedule(creds, start_time) do

    end_time = Timex.shift(start_time, [weeks: 1])

    stime = start_time |> Timex.format!("{RFC3339z}")

    params = URI.encode_query(%{"term-start" => stime})
    {:ok, res} = get(@schedule <> params, creds)

    res.body
    |> Quinn.parse
    |> Quinn.find(:entry)
    |> Enum.flat_map(fn v ->
      [%{value: [title]}] = v |> Quinn.find(:title)

      v
      |> Quinn.find(:"cbl:when")
      |> Enum.map(fn %{attr: [startTime: start_time, endTime: end_time]} ->
        %{title: title,
          start_time: Timex.parse!(start_time, "{RFC3339}") |> Timex.local,
          end_time: Timex.parse!(end_time, "{RFC3339}") |> Timex.local}
        end)
    end)
    |> Enum.filter( fn %{start_time: start} ->
      Timex.before?(start_time, start) && Timex.after?(end_time, start)
    end)
    |> Enum.sort( fn %{start_time: time1}, %{start_time: time2} ->
      Timex.compare(time1, time2) < 0
    end)

  end

  # private function

  defp get(url, creds) do
    params = OAuther.sign("get", url, [], creds)
    {header, _req_params} = OAuther.header(params)
    HTTPoison.get(url, [header])
  end

  defp today_am5 do
    today = Timex.local
    today_am5 = today |> Timex.beginning_of_day |> Timex.shift([hours: 5])

    if Timex.after?(today, today_am5) do
      today_am5
    else
      today_am5 |> Timex.shift([days: -1])
    end
  end

end
