defmodule SlackbotCybozulive.Auth do
  use GenServer

  @step_1 "https://api.cybozulive.com/oauth/initiate"
  @step_2 "https://api.cybozulive.com/oauth/authorize"
  @step_3 "https://api.cybozulive.com/oauth/token"

  require Logger

  def start_link(parent, consumer_key, consumer_secret) do
    GenServer.start_link(__MODULE__, [parent, consumer_key, consumer_secret])
  end

  def auth_start(self) do
    GenServer.cast(self, :auth_start)
  end

  def auth_verify(self, verifier) do
    GenServer.cast(self, {:auth_verifier, verifier})
  end

  def init([parent, consumer_key, consumer_secret]) do
    creds = OAuther.credentials(consumer_key: consumer_key, consumer_secret: consumer_secret)

    {:ok, %{parent: parent, creds: creds}}
  end

  def handle_cast(:auth_start, %{parent: parent, creds: creds} = state) do
    Logger.debug "auth_start"

    params = OAuther.sign("get", @step_1, [], creds)

    {header, _req_params} = OAuther.header(params)

    {:ok, res}= HTTPoison.get(@step_1, [header])

    %{"oauth_token" => oauth_token, "oauth_token_secret" => oauth_token_secret} =
      URI.decode_query(res.body, %{})

    creds = %{creds | token: oauth_token, token_secret: oauth_token_secret}

    parent |> send({:request_verifier, self, @step_2 <> "?oauth_token=#{oauth_token}"})

    {:noreply, %{state | creds: creds}}
  end

  def handle_cast({:auth_verifier, verifier}, %{parent: parent, creds: creds} = state) do
    params = OAuther.sign("get", @step_3, [{"oauth_verifier", verifier}], creds)

    {header, _req_params} = OAuther.header(params)

    {:ok, res} = HTTPoison.get(@step_3, [header])

    %{"oauth_token" => oauth_token, "oauth_token_secret" => oauth_token_secret} =
      URI.decode_query(res.body, %{})

    parent |> send({:auth_completed, self, oauth_token, oauth_token_secret})

    Logger.debug "#{__MODULE__} auth_verifier"
    Logger.debug "#{inspect res}"

    {:noreply, state}
  end

end
