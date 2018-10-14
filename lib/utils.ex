defmodule Utils do


  # node's pid is passed and then converted to a string
  # that string is then hashed using SHA-1 ans trucated to 2^10 bits
  def hash_modulus(node_pid) do
    str_num = :erlang.pid_to_list(node_pid)
    num = :crypto.hash(:sha, str_num) |> Base.encode16
    {int_num, _} = Integer.parse(num, 16)
    rem(int_num, :math.pow(2,10) |> trunc)
  end


end






