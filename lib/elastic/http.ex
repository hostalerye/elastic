defmodule Elastic.HTTP do
  @moduledoc ~S"""
  Used to make raw calls to Elastic Search.

  Each function returns a tuple indicating whether or not the request
  succeeded or failed (`:ok` or `:error`), the status code of the response,
  and then the processed body of the response.

  For example, a request like this:

  ```elixir
    Elastic.HTTP.get("/answer/_search")
  ```

  Would return a response like this:

  ```
    {:ok, 200,
      %{"_shards" => %{"failed" => 0, "successful" => 5, "total" => 5},
        "hits" => %{"hits" => [%{"_id" => "1", "_index" => "answer", "_score" => 1.0,
            "_source" => %{"text" => "I like using Elastic Search"}, "_type" => "answer"}],
          "max_score" => 1.0, "total" => 1}, "timed_out" => false, "took" => 7}}
  ```
  """

  alias Elastic.ResponseHandler

  @doc """
  Makes a request using the GET HTTP method, and can take a body.

  ```
  Elastic.HTTP.get("/answer/_search", body: %{query: ...})
  ```

  """
  def get(url, options \\ []) do
    request(:get, url, options)
  end

  @doc """
  Makes a request using the POST HTTP method, and can take a body.
  """
  def post(url, options \\ []) do
    request(:post, url, options)
  end

  @doc """
  Makes a request using the PUT HTTP method:

  ```
  Elastic.HTTP.put("/answers/answer/1", body: %{
    text: "I like using Elastic Search"
  })
  ```
  """
  def put(url, options \\ []) do
    request(:put, url, options)
  end

  @doc """
  Makes a request using the DELETE HTTP method:

  ```
  Elastic.HTTP.delete("/answers/answer/1")
  ```
  """
  def delete(url, options \\ []) do
    request(:delete, url, options)
  end

  @doc """
  Makes a request using the HEAD HTTP method:

  ```
  Elastic.HTTP.head("/answers")
  ```
  """
  def head(url, options \\ []) do
    request(:head, url, options)
  end

  def bulk(options) do
    body = Keyword.get(options, :body, "") <> "\n"

    options =
      options
      |> Keyword.put(:body, body)
      |> Keyword.put(:is_bulk?, true)

    request(:post, "/_bulk", options)
  end

  # Private helpers

  defp request(method, url, options) do
    options =
      []
      |> Keyword.put(:method, method)
      |> Keyword.put(:url, url)
      |> Keyword.put(:headers, Keyword.new())
      |> Keyword.put(:body, Keyword.get(options, :body, %{}))
      |> Keyword.put(:query, Keyword.get(options, :query, []))

    options
    |> client()
    |> Tesla.request(options)
    |> process_response()
  end

  defp process_response(response) do
    ResponseHandler.process(response)
  end

  defp client(options) do
    middleware =
      [
        {Tesla.Middleware.BaseUrl, Application.get_env(:elastic, :base_url, "http://localhost:9200")},
        {Tesla.Middleware.Timeout, timeout: Application.get_env(:elastic, :timeout, 30_000)},
        Elastic.Middleware.AWSMiddleware,
      ]
      |> add_basic_auth_middleware(options)
      |> add_content_type_middleware_headers(options)

      Tesla.client(middleware)
  end

  defp add_content_type_middleware_headers(middleware, options) do
    case Keyword.get(options, :is_bulk?, false) do
      true ->
        middleware
        |> add_content_type_middleware_header("application/x-ndjson")
        |> add_json_middleware(:decode)

      false ->
        add_json_middleware(middleware, :full)
    end
  end

  defp add_content_type_middleware_header(middleware, content_type) do
    [{Tesla.Middleware.Headers, [{"content-type", content_type}] | middleware]
  end

  defp add_json_middleware(middleware, type) do
    case type do
      :decode ->
        [Tesla.Middleware.DecodeJson | middleware]

      :encode ->
        [Tesla.Middleware.EncodeJson  | middleware]

      :full ->
        [Tesla.Middleware.JSON | middleware]
    end
  end

  def add_basic_auth_middleware(middleware, options) do
    case Keyword.get(options, :basic_auth, Elastic.basic_auth()) do
      {username, password} ->
        [{Tesla.Middleware.BasicAuth, %{username: username, password: password}} | middleware]

      _ ->
        middleware
    end
  end
end
