defmodule GameServerWeb.RuntimeIntrospection do
  @moduledoc """
  Data providers for the admin Runtime page (`/admin/runtime`).

  Everything here is *read* from the running system — behaviours, schema
  reflection, protobuf message props, the plugin registry — rather than
  hand-maintained, so the page cannot drift from the code. The two exceptions
  are documented where they occur: hook prose is parsed from the SDK source at
  compile time (the core callbacks carry no `@doc`), and realtime events come
  from `GameServerWeb.RealtimeEvents`, which a drift test keeps honest.

  Each provider returns a list of plain maps with a precomputed lowercase
  `:search` blob the LiveView filters on.
  """

  alias Crontab.CronExpression.Composer
  alias GameServer.Hooks.Declarations
  alias GameServer.Hooks.DynamicRpcs
  alias GameServer.Hooks.HookSchemas
  alias GameServer.Hooks.KvSchemas
  alias GameServer.Hooks.PluginManager
  alias GameServer.Notifications.Types, as: NotificationTypes
  alias GameServer.Repo.AdvisoryLock
  alias GameServer.Repo.MigrationPaths
  alias GameServer.Schedule.Scheduler

  # ── Compile-time sources ────────────────────────────────────────────────
  # Both files live at the repo root; when this app is consumed as a bare dep
  # they may be absent, so everything degrades to structure-only.

  @sdk_hooks_path Path.expand("../../../../sdk/lib/game_server/hooks.ex", __DIR__)
  @env_example_path Path.expand("../../../../.env.example", __DIR__)

  if File.exists?(@sdk_hooks_path), do: @external_resource(@sdk_hooks_path)
  if File.exists?(@env_example_path), do: @external_resource(@env_example_path)

  # Parsed from the SDK mirror (the file game devs read): per-callback `@doc`
  # where present, the full typespec signature always, and the `# ... callbacks`
  # section header each one sits under. Core's @callbacks carry no docs, so the
  # SDK text is the best available source.
  @sdk_source if File.exists?(@sdk_hooks_path), do: File.read!(@sdk_hooks_path), else: ""

  @sdk_docs Regex.scan(
              ~r/@doc\s+"""\n(.*?)"""\s*\n\s*@callback\s+([a-z_0-9!?]+)\(/s,
              @sdk_source
            )
            |> Map.new(fn [_, doc, name] -> {name, String.trim(doc)} end)

  # Full `@callback name(...) :: ret` signatures, whitespace-collapsed.
  @sdk_signatures Regex.scan(
                    ~r/@callback\s+([a-z_0-9!?]+)\(.*?(?=\n  @|\n\nend|\n  #|\z)/s,
                    @sdk_source
                  )
                  |> Map.new(fn [spec, name] ->
                    {name, spec |> String.replace(~r/\s+/, " ") |> String.trim()}
                  end)

  # Order categories appear in, grouped views included. A hook maps to the first
  # match, so specific keywords come before generic ones.
  @hook_group_order ~w(Lifecycle User Lobby Group Party Chat Achievement Leaderboard Tournament Matchmaking Payments KV Other)

  @doc "Category a hook belongs to, derived from its name (not source position)."
  @spec hook_group(String.t()) :: String.t()
  def hook_group(name) do
    cond do
      name in ~w(after_startup before_stop on_custom_hook) -> "Lifecycle"
      String.contains?(name, "kv") -> "KV"
      String.contains?(name, "chat") -> "Chat"
      String.contains?(name, "achievement") -> "Achievement"
      String.contains?(name, "score") -> "Leaderboard"
      String.contains?(name, "matchmaking") -> "Matchmaking"
      String.contains?(name, "tournament") -> "Tournament"
      String.contains?(name, "purchase") or String.contains?(name, "entitlement") -> "Payments"
      String.contains?(name, "party") -> "Party"
      String.contains?(name, "group") -> "Group"
      String.contains?(name, "lobby") -> "Lobby"
      String.contains?(name, "user") -> "User"
      true -> "Other"
    end
  end

  @doc "Category order for grouped rendering."
  @spec hook_group_order() :: [String.t()]
  def hook_group_order, do: @hook_group_order

  # Parsed .env.example rows: {name, default, description, section}.

  @env_example (if File.exists?(@env_example_path) do
                  @env_example_path
                  |> File.read!()
                  |> String.split("\n")
                  |> Enum.reduce({nil, []}, fn line, {section, acc} ->
                    cond do
                      String.contains?(line, "─") ->
                        {line |> String.replace(~r/[#─\s]+/, " ") |> String.trim(), acc}

                      match = Regex.run(~r/^\s*#?\s*([A-Z][A-Z0-9_]+)=(.*)$/, line) ->
                        [_, name, rest] = match

                        # A quoted value is taken whole; otherwise the first
                        # token is the value and the remainder a description.
                        {default, desc} =
                          case String.trim(rest) do
                            "\"" <> _ = quoted ->
                              {quoted, ""}

                            other ->
                              other
                              |> String.split(~r/[ \t]{2,}| /, parts: 2)
                              |> then(fn
                                [value] -> {value, ""}
                                [value, description] -> {value, String.trim(description)}
                              end)
                          end

                        {section, [{name, default, desc, section} | acc]}

                      true ->
                        {section, acc}
                    end
                  end)
                  |> elem(1)
                  |> Enum.reverse()
                else
                  []
                end)

  @secret_pattern ~r/SECRET|TOKEN|_KEY|PASSWORD|_PASS|DSN|PRIVATE|SALT|CREDENTIAL|SIGNING/

  # ── Hooks ───────────────────────────────────────────────────────────────

  @doc "All lifecycle hook callbacks with kind, implementers, and SDK docs."
  def hooks do
    plugin_mods = Enum.map(PluginManager.hook_modules(), fn {name, mod} -> {name, mod} end)

    GameServer.Hooks.behaviour_info(:callbacks)
    |> Enum.sort()
    |> Enum.map(fn {name, arity} ->
      key = to_string(name)
      doc = Map.get(@sdk_docs, key, "")
      signature = Map.get(@sdk_signatures, key, "#{name}/#{arity}")
      section = hook_group(key)

      implementers =
        for {plugin, mod} <- plugin_mods,
            Code.ensure_loaded?(mod) and function_exported?(mod, name, arity),
            do: plugin

      kind = if GameServer.Hooks.pipeline_hook?(name, arity), do: "pipeline", else: "fanout"

      %{
        id: "#{name}/#{arity}",
        name: key,
        arity: arity,
        kind: kind,
        implemented: if(implementers == [], do: "not implemented", else: "implemented"),
        section: section,
        signature: signature,
        implementers: implementers,
        summary: doc |> String.split("\n\n", parts: 2) |> hd() |> String.replace("\n", " "),
        doc: doc,
        search:
          String.downcase(
            "#{name} #{kind} #{section} #{signature} #{Enum.join(implementers, " ")} #{doc}"
          )
      }
    end)
  end

  # ── Env vars ────────────────────────────────────────────────────────────

  @doc """
  Every documented env var (from `.env.example`) plus every `LIMIT_*` derived
  from `GameServer.Limits.defaults/0`, with live set/unset state. Secret-like
  values are masked.
  """
  def env_vars do
    # .env.example may show the same var twice (e.g. a dev and a docker
    # variant); the first occurrence wins.
    documented = @env_example |> Enum.uniq_by(&elem(&1, 0)) |> Enum.map(&env_row/1)
    known = MapSet.new(documented, & &1.name)

    limits =
      for {key, default} <- GameServer.Limits.defaults(),
          name = "LIMIT_#{key |> Atom.to_string() |> String.upcase()}",
          not MapSet.member?(known, name) do
        env_row(
          {name, to_string(default), "Limit: #{key} (#{GameServer.Limits.get(key)} in effect)",
           "Limits"}
        )
      end

    plugin =
      for var <- Declarations.env_vars() do
        env_row({var.name, var.default, var.description, "Plugin: #{var.plugin}", var.type})
      end

    Enum.sort_by(documented ++ limits ++ plugin, & &1.name)
  end

  defp env_row({name, default, desc, section}), do: env_row({name, default, desc, section, nil})

  defp env_row({name, default, desc, section, type}) do
    value = System.get_env(name)

    %{
      id: name,
      name: name,
      set: value != nil,
      state: if(value == nil, do: "unset", else: "set"),
      value: mask(name, value),
      default: to_string(default),
      type: to_string(type || guess_type(default)),
      description: desc,
      section: section || "",
      search: String.downcase("#{name} #{desc} #{section}")
    }
  end

  # .env.example gives only a default string, so the type is read back off it —
  # enough to render "true"/"3000" distinctly from free text.
  defp guess_type(default) when is_binary(default) do
    cond do
      default in ~w(true false) -> :boolean
      match?({_, ""}, Integer.parse(default)) -> :integer
      true -> :string
    end
  end

  defp guess_type(default), do: GameServer.Config.infer_type(default)

  defp mask(_name, nil), do: nil

  defp mask(name, value) do
    if Regex.match?(@secret_pattern, name), do: String.duplicate("•", 8), else: value
  end

  # ── Protobuf ────────────────────────────────────────────────────────────

  @doc """
  Every loaded protobuf message: the server's own plus every plugin's.

  Plugin messages are found by scanning each plugin's modules rather than only
  the ones registered as KV/hook schemas, so a game sees its whole wire schema
  here — including messages it has defined but not yet wired up.
  """
  def protobuf_messages do
    server = Enum.map(app_modules(:game_server_web), &{&1, "server"})

    plugin =
      for %{name: name, modules: modules} <- PluginManager.list(),
          mod <- modules,
          do: {mod, name}

    # Registered schemas can live in a plugin's deps, outside its own module
    # list, so fold them in too.
    kv = KvSchemas.all()

    registered =
      (Map.values(kv.exact) ++
         Enum.map(kv.prefixes, &elem(&1, 1)) ++
         Enum.flat_map(HookSchemas.all(), fn {_k, %{request: rq, reply: rp}} -> [rq, rp] end))
      |> Enum.map(&{&1, "plugin"})

    (server ++ plugin ++ registered)
    |> Enum.uniq_by(&elem(&1, 0))
    |> Enum.filter(fn {mod, _source} ->
      Code.ensure_loaded?(mod) and function_exported?(mod, :__message_props__, 0)
    end)
    |> Enum.map(fn {mod, source} -> proto_row(mod, source) end)
    |> Enum.sort_by(&{&1.source != "server", &1.full_name})
  end

  defp app_modules(app) do
    case :application.get_key(app, :modules) do
      {:ok, modules} -> modules
      _ -> []
    end
  end

  defp proto_row(mod, source) do
    props = mod.__message_props__()

    fields =
      props.field_props
      |> Enum.sort()
      |> Enum.map(fn {tag, fp} ->
        %{
          tag: tag,
          name: to_string(fp.name),
          type: proto_type(fp),
          repeated: fp.repeated?,
          oneof: fp.oneof != nil
        }
      end)

    full_name = Map.get(props, :full_name) || inspect(mod)

    %{
      id: inspect(mod),
      module: inspect(mod),
      full_name: full_name,
      source: source,
      syntax: to_string(props.syntax),
      field_count: length(fields),
      fields: fields,
      search:
        String.downcase(
          "#{full_name} #{inspect(mod)} #{source} #{Enum.map_join(fields, " ", & &1.name)}"
        )
    }
  end

  # Message/enum field types are module atoms ("Elixir.Foo.Bar"); scalars are
  # plain atoms like :string.
  defp proto_type(%{type: type}) when is_atom(type) and not is_nil(type) do
    if match?("Elixir." <> _, Atom.to_string(type)),
      do: short_module(type),
      else: type |> inspect() |> String.trim_leading(":")
  end

  defp proto_type(%{type: type}), do: type |> inspect() |> String.trim_leading(":")

  # ── Channels & events ───────────────────────────────────────────────────

  @doc "Channel routes from the socket registry."
  def channels do
    for {pattern, module, description} <- GameServerWeb.UserSocket.__channels__() do
      %{
        id: pattern,
        pattern: pattern,
        module: inspect(module),
        description: description,
        search: String.downcase("#{pattern} #{inspect(module)} #{description}")
      }
    end
  end

  @doc """
  Server→client events: core's drift-tested registry plus every event a plugin
  declared via `realtime_events/0` and can push with
  `GameServer.Realtime.push_to_user/3`.
  """
  def events do
    core =
      for entry <- GameServerWeb.RealtimeEvents.all() do
        Map.merge(entry, %{source: "server", id: "#{entry.topic}/#{entry.event}"})
      end

    plugin =
      for {event, description} <- Declarations.realtime_events() do
        %{
          topic: "user:*",
          event: event,
          pb: false,
          payload: "game-defined",
          description: description,
          source: "plugin",
          id: "user:*/#{event}"
        }
      end

    for entry <- core ++ plugin do
      Map.put(
        entry,
        :search,
        String.downcase("#{entry.topic} #{entry.event} #{entry.source} #{entry.description}")
      )
    end
  end

  @doc "Notification codes a client may receive, core and plugin-declared."
  def notification_types do
    plugin = Declarations.notification_types()
    core = NotificationTypes.core()

    for {code, description} <- NotificationTypes.all() do
      source = if Map.has_key?(core, code), do: "server", else: source_plugin(plugin, code)

      %{
        id: code,
        code: code,
        description: description,
        source: source,
        search: String.downcase("#{code} #{source} #{description}")
      }
    end
    |> Enum.sort_by(&{&1.source != "server", &1.code})
  end

  defp source_plugin(plugin_types, code) do
    if Map.has_key?(plugin_types, code), do: "plugin", else: "server"
  end

  # ── Data model ──────────────────────────────────────────────────────────

  @doc """
  Every Ecto schema, the server's own and each plugin's: table, fields and
  associations.

  A plugin's schemas are grouped under the plugin's name rather than its module
  namespace, so a game that ships tables gets its own box in the diagram
  automatically — no registration step.
  """
  def data_model do
    server =
      for mod <- ecto_schemas(app_modules(:game_server_core)),
          do: {mod, schema_domain(mod), "server"}

    plugin =
      for %{name: name, modules: modules} <- PluginManager.list(),
          mod <- ecto_schemas(modules),
          do: {mod, name, name}

    (server ++ plugin)
    |> Enum.uniq_by(&elem(&1, 0))
    |> Enum.map(fn {mod, domain, source} -> schema_row(mod, domain, source) end)
    |> Enum.sort_by(& &1.table)
  end

  defp ecto_schemas(modules) do
    Enum.filter(modules, fn mod ->
      Code.ensure_loaded?(mod) and function_exported?(mod, :__schema__, 1) and
        mod.__schema__(:source) != nil
    end)
  end

  defp schema_row(mod, domain, source) do
    fields =
      for f <- mod.__schema__(:fields) do
        %{name: to_string(f), type: format_ecto_type(mod.__schema__(:type, f))}
      end

    assocs =
      for a <- mod.__schema__(:associations) do
        assoc = mod.__schema__(:association, a)

        %{
          name: to_string(a),
          kind: short_module(assoc.__struct__),
          related: inspect(assoc.related),
          related_table: related_table(assoc.related),
          owner_key: to_string(assoc.owner_key)
        }
      end

    table = mod.__schema__(:source)

    %{
      id: table,
      table: table,
      domain: domain,
      source: source,
      module: inspect(mod),
      fields: fields,
      assocs: assocs,
      field_count: length(fields),
      search:
        String.downcase(
          "#{table} #{inspect(mod)} #{domain} #{source} #{Enum.map_join(fields, " ", & &1.name)}"
        )
    }
  end

  # Domain for a server schema = its namespace segment
  # (GameServer.Matchmaking.Ticket -> "Matchmaking"); two-part modules
  # (GameServer.OAuthSession) are their own domain. Plugin schemas do not go
  # through here — they are grouped by plugin name instead. Drives the
  # flowchart's subgraph boxes.
  defp schema_domain(mod) do
    case Module.split(mod) do
      ["GameServer", domain, _ | _] -> domain
      ["GameServer", name] -> name
      parts -> hd(parts)
    end
  end

  defp related_table(mod) do
    if Code.ensure_loaded?(mod) and function_exported?(mod, :__schema__, 1),
      do: mod.__schema__(:source),
      else: nil
  end

  defp format_ecto_type({:parameterized, {mod, _}}), do: short_module(mod)

  defp format_ecto_type(type) when is_atom(type),
    do: type |> inspect() |> String.trim_leading(":")

  defp format_ecto_type(other), do: inspect(other)

  defp short_module(mod), do: mod |> inspect() |> String.split(".") |> List.last()

  @doc """
  A mermaid `flowchart` of the whole schema, one `subgraph` box per domain.

  `erDiagram` has no clustering, so the all-domains overview uses a flowchart
  instead: nodes are tables listing every field, edges are foreign keys
  labelled by their column, and each domain gets a visible box. Cross-domain
  edges are drawn thicker so the seams between domains stand out.
  """
  def mermaid_domain_flowchart do
    rows = data_model()
    by_table = Map.new(rows, &{&1.table, &1})

    subgraphs =
      rows
      |> Enum.group_by(& &1.domain)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join("\n", fn {domain, tables} ->
        nodes =
          tables
          |> Enum.sort_by(& &1.table)
          |> Enum.map_join("\n", fn row ->
            fields =
              Enum.map_join(row.fields, "<br/>", fn f ->
                "<small>#{f.name} : #{f.type}</small>"
              end)

            ~s(    #{row.table}["<b>#{row.table}</b><br/>#{fields}"])
          end)

        "  subgraph dom_#{domain}[\"#{domain}\"]\n#{nodes}\n  end"
      end)

    edges =
      rows
      |> Enum.flat_map(fn row ->
        for a <- row.assocs,
            a.kind == "BelongsTo",
            a.related_table != nil,
            Map.has_key?(by_table, a.related_table) do
          cross? = by_table[a.related_table].domain != row.domain
          arrow = if cross?, do: "==>", else: "-->"
          ~s(  #{row.table} #{arrow}|#{a.owner_key}| #{a.related_table})
        end
      end)
      |> Enum.uniq()
      |> Enum.join("\n")

    "flowchart TB\n#{subgraphs}\n#{edges}\n"
  end

  # ── Plugins & dynamic RPCs ──────────────────────────────────────────────

  @doc "Loaded plugins with their hook module and export counts."
  def plugins do
    typed = HookSchemas.all()
    rpcs_by_plugin = DynamicRpcs.list_all()

    for {name, mod} <- PluginManager.hook_modules() do
      rpc_count = rpcs_by_plugin |> Map.get(name, []) |> length()
      typed_count = Enum.count(typed, fn {{plugin, _fn}, _} -> plugin == name end)

      %{
        id: name,
        name: name,
        module: inspect(mod),
        rpcs: rpc_count,
        typed_hooks: typed_count,
        search: String.downcase("#{name} #{inspect(mod)}")
      }
    end
  end

  @doc """
  Every callable plugin function, on the same basis as the config page's
  "Available functions": static module exports (signature + `@doc` from BEAM
  metadata via `GameServer.Hooks.exported_functions/1`) unioned with
  dynamically registered RPC exports. `payload` marks the typed-hook message
  pair when one is registered.
  """
  def dynamic_rpcs do
    typed = HookSchemas.all()
    dynamic_by_plugin = DynamicRpcs.list_all()
    plugins = PluginManager.hook_modules()

    static =
      for {plugin, mod} <- plugins,
          f <- GameServer.Hooks.exported_functions(mod),
          sig <- f.signatures do
        rpc_row(
          plugin,
          "#{f.name}/#{sig.arity}",
          f.name,
          sig.signature || "#{f.name}/#{sig.arity}",
          payload_for(typed, plugin, f.name),
          sig.doc || ""
        )
      end

    dynamic =
      for {plugin, _mod} <- plugins,
          export <- Map.get(dynamic_by_plugin, plugin, []) do
        meta = export[:meta] || %{}

        args =
          (meta[:args] || [])
          |> Enum.map_join(", ", fn a -> "#{a[:name]}: #{a[:type]}" end)

        rpc_row(
          plugin,
          "#{export.hook} (dynamic)",
          export.hook,
          "#{export.hook}(#{args})",
          payload_for(typed, plugin, export.hook),
          meta[:description] || ""
        )
      end

    Enum.sort_by(static ++ dynamic, & &1.id)
  end

  defp payload_for(typed, plugin, fn_name) do
    case Map.get(typed, {plugin, to_string(fn_name)}) do
      %{request: req, reply: rep} -> "protobuf (#{short_module(req)}/#{short_module(rep)})"
      nil -> "json"
    end
  end

  defp rpc_row(plugin, id_suffix, hook, signature, payload, description) do
    %{
      id: "#{plugin}/#{id_suffix}",
      plugin: plugin,
      hook: to_string(hook),
      signature: signature,
      payload: payload,
      description: description || "",
      search: String.downcase("#{plugin} #{hook} #{signature} #{payload} #{description}")
    }
  end

  # ── Ops: jobs, locks, migrations ────────────────────────────────────────

  @doc "Scheduled Quantum jobs (config-defined and plugin-registered)."
  def scheduled_jobs do
    # A `rescue` would not help here: calling a dead GenServer exits rather
    # than raising, so check the process instead.
    if Process.whereis(Scheduler) == nil, do: [], else: job_rows()
  end

  defp job_rows do
    Scheduler.jobs()
    |> Enum.map(fn {name, job} ->
      schedule = format_schedule(job.schedule)

      %{
        id: to_string(name),
        name: to_string(name),
        schedule: schedule,
        state: to_string(job.state),
        timezone: to_string(job.timezone),
        task: format_task(job.task),
        search: String.downcase("#{name} #{schedule} #{job.state}")
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  # Composer only understands cron expressions; a job registered with a
  # non-cron schedule falls back to its raw form rather than breaking the tab.
  defp format_schedule(schedule) do
    Composer.compose(schedule)
  rescue
    _ -> inspect(schedule)
  end

  defp format_task({mod, fun, args}), do: "#{inspect(mod)}.#{fun}/#{length(args)}"
  defp format_task(fun) when is_function(fun), do: inspect(fun)
  defp format_task(other), do: inspect(other)

  @doc "Advisory lock namespaces (from the registry the locks require)."
  def advisory_locks do
    for {name, id} <- AdvisoryLock.namespaces() do
      %{
        id: to_string(name),
        name: to_string(name),
        namespace_id: id,
        search: String.downcase(to_string(name))
      }
    end
    |> Enum.sort_by(& &1.namespace_id)
  end

  @doc """
  Migration status across every migration directory the deployment uses.

  Uses the same path resolution as `mix host.migrate`, so a host application's
  own migrations (not just core's) are listed — otherwise a game that ships
  tables would see an incomplete history here.
  """
  def migrations do
    GameServer.Repo
    |> Ecto.Migrator.migrations(MigrationPaths.all())
    |> Enum.map(fn {status, version, name} ->
      %{
        id: to_string(version),
        version: version,
        name: name,
        status: to_string(status),
        search: String.downcase("#{version} #{name} #{status}")
      }
    end)
    |> Enum.sort_by(& &1.version, :desc)
  rescue
    # No schema_migrations table yet, or the database is unreachable — an
    # empty list keeps the rest of the page usable.
    _ -> []
  end
end
