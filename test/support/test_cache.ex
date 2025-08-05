defmodule NebulexMnesiaAdapter.TestCache do
  use Nebulex.Cache,
    otp_app: :nebulex_mnesia_adapter,
    adapter: NebulexMnesiaAdapter
end
