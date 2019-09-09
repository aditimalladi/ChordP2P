# ChordP2P

We have implemented the chord protocol, which is a distributed lookup protocol that addresses the problem of determining the location of a node that stores a desired data item efficiently. 
Given a key, Chord maps the key onto a node. Data location can be easily implemented on top of Chord by associating a key with each data item, and storing the key/data pair at the node to which the key maps.
Chord adapts efficiently as nodes join and leave the system, and can answer queries even if the system is continuously changing. 

## What is working

We have implemented the chord protocol as described in the paper. Periodically running fix_fingers and stabilize to ensure that the values stored in the DHT is accurate and also so it is resilient to failures.

## Getting Started

**Input :** Two parameters are inputted, `numNodes` which is the number of nodes in the network and `numReqs`, which is the number if requests each node should making

**Output :** After setting up the n/w each node makes `numReqs` number of requests and the number of hops for each of these is calculated and the average is calculated

## Running the code
```
$ mix run proj3.exs 1000 10
```
#### Results
Result for running 1000 nodes with 10 requests each, gave us an average hop count of 4.8444

## Running the code for Bonus question
```
$ mix run proj3_bonus.exs 100 2 0.1
```
#### Results
Result for running 100 nodes with 2 requests each, and killing 10% of the nodes gave us an average hop count of 6.01

## Largest Problem Solved
The largest network we ran was for 10,000 nodes for 2 requests each, giving us a average hop count of 5.9844


## Authors

* **Aditi Malladi **
* **Suraj Kumar Reddy Thanugundla **
