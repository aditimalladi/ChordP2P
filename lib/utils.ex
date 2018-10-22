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

  # makes sure all the ids are unique
  def check_id(id) do
    node_list = Chief.get(MyChief)
    if (id in node_list) do
      id = id + :rand.uniform(100)
      check_id(id)
    else
      id
    end
  end

  # checks if x node exists between the nodes a and b (excluding a and b)
  def check_range_excl(x, a, b) do
    node_list = Chief.get(MyChief)
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

  # check_range_excl real_deal_inclusion
  # checks if x node exists between the nodes a and b (excluding a and including b)
  def check_range_incl(x, a, b) do
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

  # real_succ_incl key_in_range_incl
  # check if x in between (a, b]
  def key_in_range_incl(x, a, b) do
    node_list = Chief.get(MyChief)
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
        x in 0..b || x in (a + 1)..(:math.pow(2, 20) |> trunc)
    end
  end

  # real_succ_excl key_in_range_excl
  # check if x in between (a, b)
  def key_in_range_excl(x, a, b) do
    node_list = Chief.get(MyChief)
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
        last_index = length(node_list) - 1
        x in 0..(b - 1) || x in (a + 1)..(:math.pow(2, 20) |> trunc)
    end
  end

  # to find succ for current node n
  def find_succ(n, id, data) do
    [{_, state}] = :ets.lookup(data, n)
    if(Utils.key_in_range_incl(id, state[:id], state[:succ])) do
      state[:succ]
    else
      n_dash = closest_preceding_node(id, state)
      if(n_dash == n) do
        n
      else
        find_succ(n_dash, id, data)
      end
    end
  end

  # count number of hops for lookups
  def find_succ_acc(n, id, data, acc) do
    [{_, state}] = :ets.lookup(data, n)
    if(Utils.key_in_range_incl(id, state[:id], state[:succ])) do
      acc
    else
      n_dash = closest_preceding_node(id, state)
      find_succ_acc(n_dash, id, data, acc + 1)
    end
  end

  # returns the closest preceding node of id
  def closest_preceding_node(id, state) do
    finger = state[:finger_table]
    size = Enum.count(Map.keys(finger))
    list_m = Enum.reverse(1..size)
    finger_list =
      Enum.map(list_m, fn i ->
        if(Utils.key_in_range_excl(finger[i], state[:id], id)) do
          finger[i]
        end
      end)
    # ensuring no duplicate entries
    finger_list = Enum.uniq(finger_list)
    if(finger_list == [nil]) do
      state[:id]
    else
      finger_list = finger_list -- [nil]
      Enum.fetch!(finger_list, 0)
    end
  end
end
