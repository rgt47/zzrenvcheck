# Fetch URL as Text

Downloads a URL and returns the body as a character string. Returns NULL
on any error or non-zero HTTP status.

## Usage

``` r
http_get_text(url, timeout = 10, headers = NULL)
```

## Arguments

- url:

  Character. URL to fetch.

- timeout:

  Integer. Seconds before timeout. Default: 10.

- headers:

  Named character vector. Extra HTTP headers. Default: NULL.

## Value

Character string of response body, or NULL on failure.
