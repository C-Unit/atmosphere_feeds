defmodule AtmosphereFeeds.Firehose.Handler do
  @moduledoc """
  Handles firehose events, filtering for site.standard.* records.
  """

  require Logger
  alias Exosphere.ATProto.Firehose.Message
  alias AtmosphereFeeds.Resolver

  @publication_collection "site.standard.publication"
  @document_collection "site.standard.document"

  def on_event(%{type: :commit} = msg, state) do
    # Debug: log any paths containing "site.standard"
    site_standard_ops =
      Enum.filter(msg.ops, fn op ->
        op.path && String.contains?(op.path, "site.standard")
      end)

    if site_standard_ops != [] do
      Logger.warning("[Firehose] Found site.standard ops: #{inspect(site_standard_ops)}")
      Logger.warning("[Firehose] Full message: #{inspect(msg, limit: :infinity)}")
    end

    cond do
      Message.has_collection?(msg, @publication_collection) ->
        Logger.info("[Firehose] Matched publication collection")
        process_collection(msg, @publication_collection)

      Message.has_collection?(msg, @document_collection) ->
        Logger.info("[Firehose] Matched document collection")
        process_collection(msg, @document_collection)

      true ->
        :skip
    end

    state
  end

  def on_event(_msg, state), do: state

  defp process_collection(msg, collection) do
    did = msg.repo
    ops = Message.filter_by_collection(msg, collection)

    # Extract records from CAR blocks - work around CID being nil
    records = extract_records_from_car(msg.blocks, collection)

    Logger.info("[Firehose] Found #{length(records)} #{collection} records in CAR blocks")

    for op <- ops, op.action in [:create, :update] do
      rkey = extract_rkey(op.path)

      # Find the record - there should only be one per collection in a commit
      record = Enum.find(records, fn r -> r["$type"] == collection end)

      if record do
        Logger.info("[Firehose] Processing #{collection} rkey=#{rkey}")
        Task.Supervisor.start_child(
          AtmosphereFeeds.TaskSupervisor,
          fn -> process_record(collection, did, rkey, record) end
        )
      else
        Logger.warning("[Firehose] No record content found for #{collection}/#{rkey}")
      end
    end
  end

  # Extract all records from CAR blocks that match a given $type
  defp extract_records_from_car(blocks, collection) when is_binary(blocks) and byte_size(blocks) > 0 do
    alias Exosphere.ATProto.CAR

    case CAR.decode(blocks) do
      {:ok, block_map} ->
        block_map
        |> Map.values()
        |> Enum.filter(fn
          %{"$type" => type} -> type == collection
          _ -> false
        end)

      {:error, reason} ->
        Logger.warning("[Firehose] CAR decode failed: #{inspect(reason)}")
        []
    end
  end

  defp extract_records_from_car(_, _), do: []

  defp process_record(@publication_collection, did, rkey, record) do
    Logger.info("[Firehose] Processing publication: #{did}/#{rkey}")
    Resolver.resolve_and_store_publication(did, rkey, record)
  end

  defp process_record(@document_collection, did, rkey, record) do
    Logger.info("[Firehose] Processing document: #{did}/#{rkey} - #{record["title"]}")
    Resolver.resolve_and_store_document(did, rkey, record)
  end

  defp extract_rkey(path) do
    path
    |> String.split("/")
    |> List.last()
  end
end
