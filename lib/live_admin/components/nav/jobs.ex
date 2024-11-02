defmodule LiveAdmin.Components.Nav.Jobs do
  use Phoenix.LiveView

  @impl true
  def mount(_, %{"session_id" => session_id}, socket) do
    if connected?(socket),
      do: :ok = Phoenix.PubSub.subscribe(LiveAdmin.PubSub, "session:#{session_id}")

    {:ok, assign(socket, jobs: []), layout: false}
  end

  defp set_progress(socket, target_pid, progress) do
    update(socket, :jobs, fn jobs ->
      Enum.map(jobs, fn job = {pid, label, _} ->
        if target_pid == pid do
          {pid, label, progress}
        else
          job
        end
      end)
    end)
  end

  @impl true
  def handle_info({:job, pid, :start, label}, socket) do
    Process.monitor(pid)

    socket = update(socket, :jobs, fn jobs -> [{pid, label, 0.0} | jobs] end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:job, pid, :progress, progress}, socket) do
    socket = set_progress(socket, pid, progress)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:job, pid, :complete}, socket) do
    Process.send_after(self(), {:remove_job, pid}, 1500)

    {:noreply, set_progress(socket, pid, 1.0)}
  end

  @impl true
  def handle_info({:remove_job, pid}, socket) do
    socket =
      update(socket, :jobs, fn jobs ->
        Enum.filter(jobs, fn {job_pid, _, _} -> job_pid != pid end)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:DOWN, _, _, pid, _}, socket) do
    Process.send_after(self(), {:remove_job, pid}, 1000)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= for {_, label, progress} <- @jobs do %>
      <div class="job__container">
        <span class="job__label"><%= label %></span>
        <div class="job__bar" style={"width: #{progress |> Kernel.*(100) |> Float.round()}%"} />
      </div>
    <% end %>
    """
  end
end
