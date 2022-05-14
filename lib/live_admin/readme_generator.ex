defmodule LiveAdmin.READMECompiler do
  @behaviour Docout.Formatter

  @impl true
  def format(_) do
    File.cwd!
    |> Path.join("./README.md.eex")
    |> File.read!()
    |> EEx.eval_string([app_version: Application.spec(:live_admin)[:vsn]])
  end
end
