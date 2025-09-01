defmodule Mix.Tasks.Spec.Msg.Push do
  use Mix.Task
  @shortdoc "Push outbox messages (and referenced attachments) to a peer's inbox"
  @moduledoc """
  Usage:
    mix spec.msg.push --id <request_id> [--dest /path/to/peer/work/spec_requests/<id>/inbox]

  If --dest is omitted, builds it from SPEC_HANDOFF_DIR: $SPEC_HANDOFF_DIR/<id>/inbox
  """

  @impl true
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: [id: :string, dest: :string])
    id = req!(opts, :id)
    dest_inbox =
      case Keyword.get(opts, :dest) do
        nil ->
          base = System.get_env("SPEC_HANDOFF_DIR") || Mix.raise("Provide --dest or set SPEC_HANDOFF_DIR")
          Path.join([base, id, "inbox"])
        v -> v
      end

    src_root = Path.join(["work", "spec_requests", id])
    outbox = Path.join(src_root, "outbox")
    File.dir?(outbox) || Mix.raise("Outbox not found: #{outbox}")

    File.mkdir_p!(dest_inbox)

    for msg_path <- Path.wildcard(Path.join(outbox, "msg_*.json")) do
      msg = Jason.decode!(File.read!(msg_path))
      # copy message file
      File.cp!(msg_path, Path.join(dest_inbox, Path.basename(msg_path)))
      # copy attachments referenced by this message
      Enum.each(msg["attachments"] || [], fn rel_path ->
        src = Path.join(src_root, rel_path)
        target = Path.join(dest_inbox |> Path.expand(".."), rel_path) # peer's request root + rel_path
        File.mkdir_p!(Path.dirname(target))
        File.cp!(src, target)
      end)
      Mix.shell().info("Pushed #{Path.basename(msg_path)}")
    end
  end

  defp req!(opts, key), do: Keyword.get(opts, key) || Mix.raise("Missing --#{key}")
end
