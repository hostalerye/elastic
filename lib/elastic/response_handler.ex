defmodule Elastic.ResponseHandler do
  @moduledoc false

  def process({:ok, %{body: body, status: status}}) when status in 400..599 do
    {:error, status, body}
  end

  def process({:ok, %{body: body, status: status}}) do
    {:ok, status, body}
  end

  def process({:error, error}) do
    {:error, 0, error}
  end
end
