defmodule SlackbotCybozulive.Api do
    @connection "https://api.cybozulive.com/api/mpAddress/V2?"

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

    defp get(url, creds) do
      params = OAuther.sign("get", url, [], creds)
      {header, _req_params} = OAuther.header(params)
      HTTPoison.get(url, [header])
    end

end
