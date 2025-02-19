defmodule Mix.Tasks.Aoc.Get do
  @moduledoc """
  Fetch the input and example input of the AOC challenge for a given day / year.

  This mix task fetches the input and example input for the advent of code challenge of a specific
  day. The day and year of the challenge can be passed as command-line arguments or be set in the
  `advent_of_code_utils` application configuration. When neither is present, the current date is
  used.

  By default, this task stores the fetched input data in `input/<year>_<day>.txt`. The fetched
  example is stored in `input/<year>_<day>_example.txt`. If a file already exists, the matching
  input is not fetched. The destination paths can be modified by setting the value of
  `:input_path` or `:example_path` in the `advent_of_code_utils` application configuration. These
  values should be set to a string which may contain `:year` and `:day`. These values will be
  replaced by the day and year of which the input is fetched.

  For instance, the following configuration will store the fetched input data in
  `my_input/<year>/<day>.input`:

  ```
  config :advent_of_code_utils, :code_path, "my_input/:year/:day.input"
  ```

  ## Session cookie

  In order to fetch your input, this task needs your advent of code session cookie. This can be
  obtained by investigating your cookies after logging in on the advent of code website. The
  cookie can be stored inside your `config/config.exs` file (e.g.
  `config, :advent_of_code_utils, :session, "<your cookie here>"`) or it can be passed as a
  command-line argument.  If no cookie is present, the input can not be fetched.

  ## Example input

  The example input of a given day is fetched by parsing the challenge webpage of a given day and
  returning the first code example found on that page. This is generally the example input of that
  day. As this method is not foolproof, it is sometimes necessary to modify the example file by
  hand.

  If you do not wish to fetch example input, you can pass the `--no-example` flag to this task, or
  you can set `fetch_example` to `false` in the `advent_of_code_utils` application configuration.

  ## Command-line arguments

  The options below take precedence over values defined in the application configuration.

  - `-s` or `--session`: Specify the session cookie.
  - `-y` or `--year`: Specify the year.
  - `-d` or `--day`: Specify the day.
  - `--no-example`: Do not fetch example input
  - `--example`: Fetch example input
  """
  @shortdoc "Fetch AOC input"
  use Mix.Task
  alias AOC.Helpers

  def run(args) do
    {session, year, day, example} = Helpers.parse_args!(args)
    example_path = Helpers.example_path(year, day)
    input_path = Helpers.input_path(year, day)

    start_applications()
    do_if_file_does_not_exists(input_path, fn -> fetch_input(session, year, day) end)
    if example, do: do_if_file_does_not_exists(example_path, fn -> fetch_example(year, day) end)
  end

  defp do_if_file_does_not_exists(path, fun) do
    if File.exists?(path) do
      Mix.shell().info([:yellow, "* skipping ", :reset, path, " (already exists)"])
    else
      contents = fun.()
      Mix.shell().info([:green, "* creating ", :reset, path])
      path |> Path.dirname() |> File.mkdir_p!()
      File.write(path, contents)
    end
  end

  defp fetch_example(year, day) do
    case fetch('#{Mix.Tasks.Aoc.url(year, day)}') do
      {:ok, input} ->
        find_example(input)

      :error ->
        Mix.raise("Could not fetch example input. Please ensure the challenge is available.")
    end
  end

  def find_example(html) do
    with {:ok, html} <- Floki.parse_document(html),
         [{"code", [], [str | _]} | _] when is_binary(str) <- Floki.find(html, "pre code") do
      str
    else
      _ ->
        Mix.shell().info([
          :red,
          "! ",
          :reset,
          "Something went wrong while parsing the challenge",
          "\n",
          :red,
          "! ",
          :reset,
          "Example input will be empty"
        ])

        ""
    end
  end

  defp fetch_input(nil, _, _) do
    Mix.raise("Could not fetch input: no session cookie was set")
  end

  defp fetch_input(session, year, day) do
    case fetch('#{Mix.Tasks.Aoc.url(year, day)}/input', [cookie(session)]) do
      {:ok, input} ->
        input

      :error ->
        Mix.raise("""
        Could not fetch input. Please ensure:
        - Your session cookie is set up correctly
        - The challenge is available
        - There is an input today
        """)
    end
  end

  defp fetch(url, headers \\ []) do
    ca_path = Application.get_env(:advent_of_code_utils, :ca_cert_path, "/etc/ssl/cert.pem")
    headers = [user_agent() | headers]

    opts =
      if(File.exists?(ca_path), do: [ssl: [verify: :verify_peer, cacertfile: ca_path]], else: [])

    resp = :httpc.request(:get, {url, headers}, opts, [])

    case resp do
      {:ok, {{'HTTP/1.1', 200, 'OK'}, _headers, body}} -> {:ok, body}
      _ -> :error
    end
  end

  @ua_name Mix.Project.config()[:app]
  @ua_version Mix.Project.config()[:version]
  @ua_contact "github.com/mathsaey/advent_of_code_utils by contact@mathsaey.be"
  @ua_charlist to_charlist("#{@ua_name}/#{@ua_version} #{@ua_contact}")

  defp user_agent, do: {'User-Agent', @ua_charlist}
  defp cookie(session), do: {'Cookie', to_charlist("session=#{session}")}

  defp start_applications do
    :ok = Application.ensure_started(:inets)
    :ok = Application.ensure_started(:crypto)
    :ok = Application.ensure_started(:asn1)
    :ok = Application.ensure_started(:public_key)
    :ok = Application.ensure_started(:ssl)
  end
end
