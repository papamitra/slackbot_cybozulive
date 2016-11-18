defmodule SlackbotCybozulive.Supervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    children = [
      supervisor(SlackbotCybozulive.AuthSupervisor, []),
      supervisor(SlackbotCybozulive.WorkerSupervisor, []),
      worker(SlackbotCybozulive.AuthServer, []),
      worker(SlackbotCybozulive.Server, []),
    ]

    opts = [strategy: :one_for_one]

    supervise(children, opts)
  end

end
