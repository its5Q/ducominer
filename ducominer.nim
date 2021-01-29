import hashlib/rhash/sha1
import net, httpclient
import json
import strutils, strformat
import threadpool
import os

proc recvAll(s: Socket): string =   # Function for receiving an arbitrary amount of data from the socket
    var res = ""
    res = res & s.recv(1, timeout=45000)
    while s.hasDataBuffered():
        res = res & s.recv(1, timeout=45000)       
    return res

proc mine(username: string, pool_ip: string, pool_port: Port, difficulty: string, miner_name: string) {.thread.} =  # Mining functions executed in multiple threads
    var soc: Socket = newSocket()   # Creating a new TCP socket
    soc.connect(pool_ip, pool_port) # Connecting to the mining server
    discard soc.recv(3, timeout=45000)  # Receiving the server version and voiding it

    echo fmt"Thread #{getThreadId()} connected to {pool_ip}:{pool_port}"

    var job: seq[string] 
    var feedback: string

    while true: # An infinite loop of requesting and solving jobs
        if difficulty == "NORMAL":  # Checking if the difficulty is set to "NORMAL" and sending a job request to the server
            soc.send(fmt"JOB,{username}")
        else:
            soc.send(fmt"JOB,{username},{difficulty}")
        job = soc.recvAll().split(",")  # Receiving a job from the server that is comma-separated
        for result in 0..100 * parseInt(job[2]):    # A loop for solving the job
            if $count[RHASH_SHA1](job[0] & $(result)) == job[1]:    # Checking if the hashes of the job matches our hash
                soc.send($(result) & ",," & miner_name) # Sending the result to the server
                feedback = soc.recvAll()    # Receiving feedback from the server
                if feedback == "GOOD":  # Checking the server feedback
                    echo fmt"Accepted share {result} with a difficulty of {parseInt(job[2])}"
                elif feedback == "BAD":
                    echo fmt"Rejected share {result} with a difficulty of {parseInt(job[2])}"
                break # Breaking from the loop, as the job was solved

var config: JsonNode
if paramCount() < 1:
    try:
        echo "Config file location not specified, using default location [./config.json]"
        config = parseJson(readFile("./config.json"))   # Parsing a JSON config
    except:
        echo "Config not found at default location. Please specify the config file location."
        echo ""
        echo fmt"Usage: {paramStr(0)} <config file>"
        echo "You can find an example config file at https://github.com/its5Q/ducominer/config.example.json"
        quit(1)
else:
    config = parseJson(readFile(paramStr(1)))   # Parsing a JSON config

let client: HttpClient = newHttpClient()    # Creating a new HTTP client

var pool_address: string = client.getContent(config["ip_url"].getStr()) # Making a request to the URL specified in the config for getting mining server details

var pool_ip: string = pool_address.split("\n")[0]   # Parsing the server IP
var pool_port: Port = Port(parseInt(pool_address.split("\n")[1]))   # Parsing the server port

var username = config["username"].getStr(default = "5Q")
var difficulty = config["difficulty"].getStr(default = "NORMAL")  
var miner_name = config["miner_name"].getStr(default = "DUCOMiner-Nim")
var thread_count = config["thread_count"].getInt(default = 16)

for i in countup(0, thread_count - 1):  # A loop that spawns new threads executing the mine() function
    spawn mine(username, pool_ip, pool_port, difficulty, miner_name)
sync()  # Synchronizing the threads so the program doesn't exit until Ctrl+C is pressed or an exception is raised