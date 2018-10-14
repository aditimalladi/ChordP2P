# :observer.start()
Process.register self(), Main
[numNodes, numReq] = System.argv

{numNodes, _} = Integer.parse(numNodes)
{numReq, _} = Integer.parse(numReq)

