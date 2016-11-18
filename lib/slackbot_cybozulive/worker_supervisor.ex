defmodule SlackbotCybozulive.WorkerSupervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    worker_opts = [restart: :temporary]
    children = [worker(SlackbotCybozulive.Worker, [], worker_opts)]

    opts = [
      strategy: :simple_one_for_one
    ]

    supervise(children, opts)
  end

end
