defmodule Hound.RequestUtils do
  @moduledoc false

  def make_req(type, path, params \\ %{}, options \\ %{}, retries \\ retries())
  def make_req(type, path, params, options, 0) do
    send_req(type, path, params, options)
  end
  def make_req(type, path, params, options, retries) do
    try do
      case send_req(type, path, params, options) do
        {:error, _} -> make_retry(type, path, params, options, retries)
        result      -> result
      end
    rescue
      _ -> make_retry(type, path, params, options, retries)
    catch
      _ -> make_retry(type, path, params, options, retries)
    end
  end

  defp make_retry(type, path, params, options, retries) do
    :timer.sleep(Application.get_env(:hound, :retry_time, 250))
    make_req(type, path, params, options, retries - 1)
  end

  defp send_req(type, path, params, options) do
    url = get_url(path)
    has_body = params != %{} && type == :post
    {headers, body} = cond do
       has_body && options[:json_encode] != false ->
        {[{"Content-Type", "text/json"}], Jason.encode!(params)}
      has_body ->
        {[], params}
      true ->
        {[], ""}
    end

    hackney_http_options = http_options()

    # IO.inspect(%{
    #   type: type,
    #   url: url, 
    #   headers: headers, 
    #   body: body, 
    #   http_options: [:with_body | hackney_http_options]
    # }, label: :hackney_request)

    :hackney.request(type, url, headers, body, [:with_body | hackney_http_options])
    #|> IO.inspect(label: :hackney_response1)
    |> handle_response({url, path, type}, options)
    #|> IO.inspect(label: :hackney_response2)
  end

  defp handle_response({:ok, code, headers, body}, {url, path, type}, options) do
    # IO.inspect(%{
    #     code: code, 
    #     headers: headers, 
    #     body: body, 
    #     url: url, 
    #     path: path, 
    #     type: type, 
    #     options: options,
    #     parsed: Hound.ResponseParser.parse(response_parser(), path, code, headers, body)
    #   }, 
    #   label: :handle_response)

    case Hound.ResponseParser.parse(response_parser(), path, code, headers, body) do
      :error ->
        raise """
        Webdriver call status code #{code} for #{type} request #{url}.
        Check if webdriver server is running. Make sure it supports the feature being requested.
        """
      {:error, err} = value ->
        if options[:safe],
          do: value,
          else: raise err
      response -> response
    end
  end

  defp handle_response({:error, reason}, _, _) do
    {:error, reason}
  end

  defp response_parser do
    {:ok, driver_info} = 
      Hound.driver_info()
      #|> IO.inspect(label: :response_parser)

    case {driver_info.driver, driver_info.browser} do
      {"selenium", "chrome" <> _headless} ->
        Hound.ResponseParsers.ChromeDriver

      {"selenium", _} ->
        Hound.ResponseParsers.Selenium

      {"chrome_driver", _} ->
        Hound.ResponseParsers.ChromeDriver

      {"phantomjs", _} ->
        Hound.ResponseParsers.PhantomJs

      other_driver ->
        raise "No response parser found for #{other_driver}"
    end
  end

  defp get_url(path) do
    {:ok, driver_info} = Hound.driver_info

    host = driver_info[:host]
    port = driver_info[:port]
    path_prefix = driver_info[:path_prefix]

    "#{host}:#{port}/#{path_prefix}#{path}"
  end

  defp http_options() do
    Application.get_env(:hound, :http, [])
  end

  defp retries() do
    Application.get_env(:hound, :retries, 0)
  end
end
