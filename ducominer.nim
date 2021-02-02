import std / [
  net,
  strutils, strformat, strscans,
  threadpool, atomics,
  os, times,
  json, httpclient
]

import nimcrypto/sha

const
    monitorInterval = 7500

var 
  startTime: Time
  acceptedCnt, rejectedCnt, hashesCnt, currentDifficulty: Atomic[int]

# Function for receiving an arbitrary amount of data from the socket
proc recvAll(s: Socket): string =   
    result = s.recv(1, timeout=30000)
    while s.hasDataBuffered():
        result &= s.recv(1, timeout=30000)

proc minerThread(username: string, pool_ip: string, pool_port: Port, difficulty: string, miner_name: string) {.thread.} =  # Mining functions executed in multiple threads
    # Connecting to the server and discarding the server verison
    var soc: Socket = newSocket()
    soc.connect(pool_ip, pool_port)
    discard soc.recvAll() 

    # echo fmt"Thread #{getThreadId()} connected to {pool_ip}:{pool_port}"

    while true:
        # Checking if the difficulty is set to "NORMAL" and sending a job request to the server
        if difficulty == "NORMAL":  
            soc.send(fmt"JOB,{username}")
        else:
            soc.send(fmt"JOB,{username},{difficulty}")
        
        # Receiving and parsing the job from the server
        var job = soc.recvAll()
        var
            prefix, target: string
            diff: int        
        if not scanf(job, "$+,$+,$i", prefix, target, diff):
            quit("Error: couldn't parse job from the server!")
        target = target.toUpper()
        currentDifficulty.store(diff)

        # Initialize the sha1 context and add prefix
        var ctx: sha1
        ctx.init()
        ctx.update(prefix)

        # A loop for solving the job
        for res in 0 .. 100 * diff:
            # Copy the initialized context and add the value
            var ctxCopy = ctx
            ctxCopy.update($res)

            # Checking if the hash of the job matches our hash
            if $ctxCopy.finish() == target:
                hashesCnt.atomicInc(res)
                soc.send(fmt"{$res},,{miner_name}")

                # Receiving and checking the feedback from the server
                let feedback = soc.recvAll()    
                if feedback == "GOOD":  # Checking the server feedback
                    acceptedCnt.atomicInc()
                elif feedback == "BAD":
                    rejectedCnt.atomicInc()
    
                # Breaking from the loop, because the job was solved
                break 
        

proc monitorThread() {.thread.} =
    startTime = getTime()
    echo fmt"Statistics update interval: {monitorInterval / 1000} seconds"
    while true:
        sleep(monitorInterval)
        # Get time diff in milliseconds
        let mils = (getTime() - startTime).inMilliseconds.float

        # Calculate amount of hashes per second
        let hashesSec = (hashesCnt.load().float / mils) * 1000
        let khsec = hashesSec / 1000
        let mhsec = khsec / 1000
        let toShow = if mhsec >= 1:
            mhsec.formatFloat(ffDecimal, 2) & " MH/s"
        elif khsec >= 1:
            khsec.formatFloat(ffDecimal, 2) & " KH/s"
        else:
            hashesSec.formatFloat(ffDecimal, 2) & " H/s"

        startTime = getTime()
        let strTime = startTime.format("HH:mm:ss")
        echo fmt"{strTime} Hashrate: {toShow}, Accepted: {acceptedCnt.load()}, Rejected: {rejectedCnt.load()}, Difficulty: {currentDifficulty.load()}"

        # Resetting hash count
        hashesCnt.store(0)


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

var pool_address: seq[string] = client.getContent(config["ip_url"].getStr()).split("\n") # Making a request to the URL specified in the config for getting mining server details

var pool_ip: string = pool_address[0]   # Parsing the server IP
var pool_port: Port = Port(parseInt(pool_address[1]))   # Parsing the server port

var username = config["username"].getStr()
var difficulty = config["difficulty"].getStr()  
var miner_name = config["miner_name"].getStr()
var thread_count = config["thread_count"].getInt()

# Starting mining threads and the monitor thread
for i in 0 ..< thread_count:
    spawn minerThread(username, pool_ip, pool_port, difficulty, miner_name)
    sleep(300)
echo "Started all mining threads"
spawn monitorThread()

# Synchronizing the threads so the program doesn't exit until Ctrl+C is pressed or an exception is raised
sync()  