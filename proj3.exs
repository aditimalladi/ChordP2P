:observer.start()
Process.register self(), Main
[numNodes, numReq] = System.argv

{numNodes, _} = Integer.parse(numNodes)
{numReq, _} = Integer.parse(numReq)


{:ok, chief_pid} = Chief.start_link([])
Process.register chief_pid, MyChief

Enum.each(0..numNodes-1, fn(i)->
  {:ok, node_pid} = NwNode.start_link([])
  Chief.update_kash(chief_pid, Utils.hash_modulus(node_pid), node_pid)
  Utils.hash_modulus(node_pid)
  Chief.put(chief_pid, Utils.hash_modulus(node_pid))
  :timer.sleep(100)
end)

node_list = Chief.get(MyChief)

:timer.sleep(1000)

first_node = Enum.fetch!(node_list, 0)
node_list = node_list -- [first_node]
first_node_pid = Chief.lookup(MyChief, first_node)

NwNode.create(first_node_pid)

Enum.each(node_list, fn(node)->
  node_list
  node_pid = Chief.lookup(MyChief, node)
  NwNode.join(node_pid, first_node)
end)


:timer.sleep(10000000)