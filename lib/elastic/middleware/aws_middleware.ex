defmodule Elastic.Middleware.AWSMiddleware do
  @behaviour Tesla.Middleware

  alias Elastic.AWS

  @impl Tesla.Middleware
  def call(env, next, _opts) do
    if AWS.enabled?() do
      env
      |> Tesla.put_headers(aws_headers(env))
      |> Tesla.run(next)
    else
      Tesla.run(env, next)
    end
  end

  defp aws_headers(env) do
    AWS.authorization_headers(
      env.method,
      env.url,
      env.headers,
      env.body
    )
  end
end
