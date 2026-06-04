defmodule Onchain.MixProject do
  use Mix.Project

  @version "0.5.4"
  @source_url "https://github.com/ZenHive/onchain"

  def project do
    [
      app: :onchain,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps(),
      dialyzer: dialyzer(),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def cli do
    [
      preferred_envs: [
        "test.json": :test,
        "dialyzer.json": :dev
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:cartouche, "~> 0.2.1"},
      {:decimal, "~> 3.1.1"},
      {:descripex, "~> 0.7.0"},
      {:jason, "~> 1.4"},
      {:zen_websocket, "~> 0.4.2"},

      # Dev/test tooling
      {:tidewave, "~> 0.5.6", only: :dev},
      {:bandit, "~> 1.0", only: :dev},
      {:ex_unit_json, "~> 0.5.0", only: [:dev, :test], runtime: false},
      {:dialyzer_json, "~> 0.2.0", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.23.0", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false},
      {:ex_dna, "~> 1.3", only: [:dev, :test], runtime: false},
      {:ex_ast, "~> 0.12.0", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.7.1", only: [:dev, :test], runtime: false},
      {:boxart, "~> 0.3.3", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "Shared Ethereum/blockchain library for read (eth_call) and write (transaction signing) operations using cartouche."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "Onchain",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp aliases do
    [
      tidewave: [
        "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Tidewave, port: 4007) end)'"
      ],
      # Shadow the dialyzer.json task to seed the PLTs first (Task 75).
      "dialyzer.json": &seed_then_dialyzer_json/1
    ]
  end

  # 30 min — far beyond any real dialyzer run (~150-190s here), so the only lock
  # this age can belong to is a crashed run that never released. See
  # with_dialyzer_lock/1.
  @dialyzer_lock_stale_s 1800

  # Serialize, then seed, then run the real dialyzer.json task.
  # Mix.Task.get!/1 resolves the task NAME to its module (it does not consult
  # aliases, so this can't re-trigger the alias above); loadpaths first puts the
  # dep's ebin on the code path so the module is loadable.
  defp seed_then_dialyzer_json(args) do
    with_dialyzer_lock(fn ->
      seed_plts()
      Mix.Task.run("loadpaths")
      apply(Mix.Task.get!("dialyzer.json"), :run, [args])
    end)
  end

  # Task 75 — the actual OOM fix. A single dialyzer run on onchain's dep graph
  # peaks at ~30 GB regardless of seeding: the main checkout hits ~36 GB with a
  # fully cached PLT, and trimming plt_add_apps doesn't lower it (it only loses
  # ABI coverage). The 2026-06-04 host OOM came from FOUR concurrent runs (the
  # harness reviewer's check_command under concurrency_cap=4), not from any one
  # avoidable build — so the lever onchain owns is to let only ONE run at a time.
  #
  # macOS (the host that OOM'd) has no flock(1), so we use an atomic mkdir lock
  # at a host-global path (see dialyzer_lock_path/0) shared across all
  # worktrees: File.mkdir/1 succeeds for exactly one process and returns :eexist
  # to the rest, who spin-wait. A lock older than @dialyzer_lock_stale_s (a
  # crashed run that never reached the `after`) is reclaimed so a dead process
  # can't wedge the host.
  defp with_dialyzer_lock(fun) do
    lock = dialyzer_lock_path()
    File.mkdir_p!(Path.dirname(lock))
    acquire_dialyzer_lock(lock)

    try do
      fun.()
    after
      File.rmdir(lock)
    end
  end

  # Host-global, TMPDIR-independent: every worktree (and the harness reviewer)
  # must resolve the SAME path for the lock to serialize them. System.tmp_dir!/0
  # is wrong here — the sandbox points TMPDIR at a per-session dir, so locks
  # wouldn't collide. The user home is constant across all worktrees and runs.
  defp dialyzer_lock_path do
    Path.join([System.user_home!(), ".cache", "onchain-dialyzer.lock"])
  end

  defp acquire_dialyzer_lock(lock, waited \\ false) do
    case File.mkdir(lock) do
      :ok ->
        :ok

      {:error, :eexist} ->
        reclaim_if_stale(lock)
        if !waited, do: Mix.shell().info("Waiting for onchain dialyzer lock (#{lock})…")
        Process.sleep(2000)
        acquire_dialyzer_lock(lock, true)

      {:error, reason} ->
        Mix.raise("Could not acquire dialyzer lock #{lock}: #{:file.format_error(reason)}")
    end
  end

  defp reclaim_if_stale(lock) do
    case File.stat(lock, time: :posix) do
      {:ok, %File.Stat{mtime: mtime}} ->
        if System.os_time(:second) - mtime > @dialyzer_lock_stale_s do
          Mix.shell().info("Reclaiming stale dialyzer lock (#{lock})")
          File.rmdir(lock)
        end

      _ ->
        :ok
    end
  end

  # Task 75 time-saver (NOT the OOM fix — with_dialyzer_lock/1 is). priv/plts is
  # gitignored, so a fresh harness worktree has none and dialyxir rebuilds every
  # PLT from zero. When invoked from a linked git worktree, copy the main
  # checkout's already-built PLTs into this worktree's priv/plts: the OTP and
  # OTP+elixir CORE PLTs seed cleanly (their beams live in the shared asdf
  # install at a constant path, so dialyxir's per-beam md5 check passes — ~5s
  # verify instead of a full core build). The deps PLT copy is effectively
  # wasted — dep beam debug_info embeds the absolute worktree path, so its md5s
  # differ per worktree and dialyxir rebuilds it regardless — but copying it is
  # cheap and harmless, and dialyxir self-heals it (Dialyxir.Plt.plt_check only
  # refreshes changed beams). Each worktree writes only its OWN priv/plts (the
  # shared source is read-only), so this can't race. No-op in the main checkout,
  # when the destination is already seeded, or when no source is reachable.
  defp seed_plts do
    dest = Path.expand("priv/plts")

    with source when is_binary(source) <- main_checkout_plts(),
         false <- plts_present?(dest),
         true <- plts_present?(source) do
      File.mkdir_p!(dest)

      Enum.each(plt_files(source), fn file ->
        File.cp!(file, Path.join(dest, Path.basename(file)))
      end)
    else
      _ -> :ok
    end
  end

  # Main checkout's priv/plts when invoked from a LINKED worktree, else nil.
  # `git rev-parse --git-common-dir` returns an absolute path ending in ".git"
  # inside a worktree, and the literal relative ".git" in the main checkout.
  defp main_checkout_plts do
    case System.cmd("git", ["rev-parse", "--git-common-dir"], stderr_to_stdout: true) do
      {out, 0} ->
        common = String.trim(out)
        if Path.type(common) == :absolute, do: Path.join([Path.dirname(common), "priv", "plts"])

      _ ->
        nil
    end
  end

  # All dialyxir PLT artifacts (the OTP and OTP+elixir cores, the deps PLT, and
  # its hash sidecar). Globbed so OTP/elixir versions aren't hardcoded.
  defp plt_files(dir), do: Path.wildcard(Path.join(dir, "dialyxir_*"))
  defp plts_present?(dir), do: plt_files(dir) != []

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp dialyzer do
    [
      # OOM mitigation: skip transitive deps (default is :app_tree).
      # Tidewave/bandit's HTTP stack (plug, finch, mint, gun, cowlib, etc.)
      # is not in lib/'s call graph and bloats PLT to ~800 modules.
      plt_add_deps: :apps_direct,
      plt_add_apps: [:mix, :hieroglyph],
      # OOM mitigation, part 2 (Task 75): a single dialyzer run on this dep graph
      # peaks at ~30 GB and that floor is irreducible (the main checkout hits
      # ~36 GB with a fully cached PLT; trimming plt_add_apps doesn't lower it).
      # The 2026-06-04 host OOM was FOUR such runs at once (harness reviewer
      # under concurrency_cap=4), so the fix lives in the "dialyzer.json" alias
      # (aliases/0 -> with_dialyzer_lock/1): a host-global mkdir lock serializes
      # runs to one-at-a-time. seed_plts/0 additionally reuses the main
      # checkout's core PLTs to skip the per-worktree core build (a time-saver,
      # not the OOM fix). Paths stay priv/plts, so main-checkout behavior is
      # unchanged.
      plt_local_path: "priv/plts",
      plt_core_path: "priv/plts"
    ]
  end
end
