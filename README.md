# ducominer
 A multithreaded miner for [DuinoCoin](https://github.com/revoxhere/duino-coin "DuinoCoin") written in Nim.
 
### Installation
You can install the miner using 2 methods:
- Downloading a precompiled version on the [Releases](https://github.com/its5Q/ducominer/releases "Releases") page [Recommended]
- Installing it using Nimble package manager
```nimble install ducominer```

If you are on Linux, you need to install 2 dependencies for the hashing library: ```libgcrypt20``` and ```libgcrypt20-dev```

### Usage
The usage is pretty simple. The miner can be started like that:
```ducominer <config file>```
where ```<config file>``` is a path to the config file. If you downloaded a precompiled version, there will be file named config.example.json that you can edit. If you installed the miner using nimble, you need to download an example config file from the repository.

### Credits
Thanks to [@revoxhere](https://github.com/revoxhere) for creating DuinoCoin that is open-source and open for anyone to contribute.
