defmodule Utils do


  # node's pid is passed and then converted to a string
  # that string is then hashed using SHA-1 ans trucated to 2^10 bits
  def hash_modulus(node_pid) do
    str_num = :erlang.pid_to_list(node_pid)
    num = :crypto.hash(:sha, str_num) |> Base.encode16
    {int_num, _} = Integer.parse(num, 16)
    rem(int_num, :math.pow(2,10) |> trunc)
  end

  # to check if the given node is in the given range
  def check_in_range(x, a, b, accumulator) do
    a_pid = Chief.lookup(MyChief, a)
    succ = Peer.get_successor(a_pid)
    if a == b do
      if x == a do
        true
      else
        accumulator
      end
    else
      check_in_range(x, succ, b, (a.succ == x) || accumulator)
    end
  end




end