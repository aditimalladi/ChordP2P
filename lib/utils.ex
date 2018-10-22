defmodule Utils do
  # node's pid is passed and then converted to a string
  # that string is then hashed using SHA-1 ans trucated to 2^20 bits
  def hash_modulus(node_name) do
    str_num = Atom.to_string(node_name)
    num = :crypto.hash(:sha, str_num) |> Base.encode16
    {int_num, _} = Integer.parse(num, 16)
    id = rem(int_num, :math.pow(2,20) |> trunc)
    check_id(id)
  end

  def check_id(id) do
    node_list = Chief.get(MyChief)
    if (id in node_list) do
      id = id + :rand.uniform(100)
      check_id(id)
    else
      id
    end
  end

  # # for when a == self()
  # def check_in_range_self(x, a, b, accumulator, state) do
  #   a_pid = Chief.lookup(MyChief, a)
  #   succ = state[:succ]
  #   succ_pid = Chief.lookup(MyChief, succ)

  #   if a == b do
  #     if x == a do
  #       true
  #     else
  #       accumulator
  #     end
  #   else
  #     if(x == succ) do
  #       # HERE
  #       state = Peer.get_state(succ_pid)
  #       check_in_range_self(x, succ, b, succ == x || accumulator, state)
  #     else
  #       check_in_range(x, succ, b, succ == x || accumulator)
  #     end
  #   end
  # end

  # # to check if the given node is in the given range
  # def check_in_range(x, a, b) do
  #   [{_, a_state}] = :ets.lookup(:data, a)
  #   # IO.puts "Check in range NOT SELF #{x} #{a} #{b} HC"
  #   succ = a_state[:succ]
  #   if a == b do
  #     if x == a do
  #       true
  #     else
  #       false
  #     end
  #   else
  #     if(x == succ) do
  #       true
  #     else
  #       check_in_range(x, succ, b)
  #     end
  #   end
  # end

  def real_deal_exclusion(x, a, b) do
    # IO.puts "REAL DEAL MOFOOOOOO #{x} #{a} #{b} HC"
    # IO.inspect x
    # IO.inspect a
    # IO.inspect b
    node_list = Chief.get(MyChief)
    # IO.inspect node_list
    cond do
      a == nil || b == nil || x == nil ->
        false

      a not in node_list || b not in node_list ->
        false

      a == b ->
        false

      a < b ->
        index_a = Enum.find_index(node_list, fn i -> i == a end)
        index_b = Enum.find_index(node_list, fn i -> i == b end)
        # IO.puts("#{a} this is a")
        # IO.puts("#{b} this is b")
        # IO.puts("#{index_a} this is a_index")
        # IO.puts("#{index_b} this is b_index")
        # IO.puts("#{index_b - index_a - 1} this is idk what")
        check_list = Enum.slice(node_list, index_a + 1, index_b - index_a - 1)
        x in check_list

      a > b ->
        index_a = Enum.find_index(node_list, fn i -> i == a end)
        index_b = Enum.find_index(node_list, fn i -> i == b end)
        last_index = length(node_list) - 1
        checklist_1 = Enum.slice(node_list, index_a + 1, last_index)
        checklist_2 = Enum.slice(node_list, 0, index_b)
        x in checklist_1 || x in checklist_2
    end
  end

  def real_deal_inclusion(x, a, b) do
    # IO.puts "INCLUSION REAL DEAL #{x} #{a} #{b}"
    node_list = Chief.get(MyChief)

    cond do
      x == nil ->
        false

      a == b ->
        false

      a < b ->
        index_a = Enum.find_index(node_list, fn i -> i == a end)
        index_b = Enum.find_index(node_list, fn i -> i == b end)
        check_list = Enum.slice(node_list, index_a + 1, index_b - index_a)
        x in check_list

      a > b ->
        index_a = Enum.find_index(node_list, fn i -> i == a end)
        index_b = Enum.find_index(node_list, fn i -> i == b end)
        last_index = length(node_list) - 1
        checklist_1 = Enum.slice(node_list, index_a + 1, last_index)
        checklist_2 = Enum.slice(node_list, 0, index_b + 1)
        x in checklist_1 || x in checklist_2
    end
  end

  def real_succ_incl(x, a, b) do
    # IO.puts "REAL SUCC INCL #{x} #{a} #{b} HC"
    node_list = Chief.get(MyChief)
    # IO.inspect node_list
    cond do
      a == nil || b == nil || x == nil ->
        false

      a == b ->
        if(x == a) do
          true
        else
          false
        end

      a < b ->
        x in (a + 1)..b

      a > b ->
        # split into 2 parts 
        # last_index = length(node_list) - 1
        # last_ele = Enum.fetch!(node_list, last_index)
        x in 0..b || x in (a + 1)..(:math.pow(2, 20) |> trunc)
    end
  end

  def real_succ_excl(x, a, b) do
    # IO.puts "REAL SUCC EXCL #{x} #{a} #{b} HC"
    node_list = Chief.get(MyChief)
    # IO.inspect node_list
    cond do
      a == nil || b == nil || x == nil ->
        false

      a == b ->
        if(x == a) do
          true
        else
          false
        end

      a < b ->
        x in (a + 1)..(b - 1)

      a > b ->
        # split into 2 parts 
        last_index = length(node_list) - 1
        # last_ele = Enum.fetch!(node_list, last_index)
        x in 0..(b - 1) || x in (a + 1)..(:math.pow(2, 20) |> trunc)
    end
  end

  def find_succ(n, id, data) do
    # IO.puts "Is this being called continously"
    [{_, state}] = :ets.lookup(data, n)

    if(Utils.real_succ_incl(id, state[:id], state[:succ])) do
      state[:succ]
    else
      n_dash = closet_preceding_node(id, state)

      if(n_dash == n) do
        n
      else
        find_succ(n_dash, id, data)
      end
    end
  end

  def find_succ_acc(n, id, data, acc) do
    [{_, state}] = :ets.lookup(data, n)

    if(Utils.real_succ_incl(id, state[:id], state[:succ])) do
      acc
    else
      n_dash = closet_preceding_node(id, state)
      find_succ_acc(n_dash, id, data, acc + 1)
    end
  end

  def closet_preceding_node(id, state) do
    finger = state[:finger_table]
    size = Enum.count(Map.keys(finger))
    list_m = Enum.reverse(1..size)

    finger_list =
      Enum.map(list_m, fn i ->
        if(Utils.real_succ_excl(finger[i], state[:id], id)) do
          finger[i]
        end
      end)

    finger_list = Enum.uniq(finger_list)
    # here is what can be returned from the function
    if(finger_list == [nil]) do
      state[:id]
    else
      finger_list = finger_list -- [nil]
      Enum.fetch!(finger_list, 0)
    end
  end

  def lookup_node(source, dest, accumulator) do
    IO.puts("AC source #{source}")
    IO.puts("AC dest #{dest}")
    node_list = Chief.get(MyChief)
    source_pid = Chief.lookup(MyChief, source)
    succ = Peer.find_succ(source_pid, dest)
    IO.puts("AC succ #{succ}")

    if(succ == dest) do
      IO.puts("Match")
      accumulator
    else
      IO.puts("Again")
      lookup_node(succ, dest, accumulator + 1)
    end
  end
end
