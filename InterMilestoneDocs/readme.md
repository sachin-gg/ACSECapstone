# Commands used to create and set up nodes and accounts

## Download package information (pre-requisite for all nodes)
      sudo apt update
      sudo apt-get update
      sudo add-apt-repository -y ppa:ethereum/ethereum
      
## Install Ethereum and Geth (pre-requisite for all nodes)
      sudo apt-get install ethereum
      sudo apt-get upgrade geth

## Create an eaglepoa (Step 1) (for all nodes)
      mkdir eaglepoa
      cd eaglepoa

## Create an Account on Node - Eagle1 (Step 2)
      mkdir eagle1
      cd eagle1
      geth --datadir ./data account new
      enter password
      store public address
      create <eagle1.txt>; open file and enter password; save file
      cd ..

>Created Eagle1 (miner) Public Address: 0x168AaBAc0c700eF95269b0876931F6ECbBbbE597
>Created 4 customer accounts
      account2: 0xd9cAa7ecb5500c5FafcA1F4A954Db75EA34c3361
      account3: 0xA4A19c7b7cAfE09063498F697E647971dC236dca
      account4: 0xE69F4c213c19a6E421869e3a62162f92dDE3050E
      account5: 0x0F97E2dFA64A4ceDcAd9F2Ad5f00578308d73b2e

## Create an Account on Node - Eagle2 (Step 3)
      mkdir eagle2
      cd eagle2
      geth --datadir ./data account new
      enter password
      store public address
      create <eagle2.txt>; open file and enter password; save file
      cd ..

>Created Eagle2(miner) Public Address: 0xc2bdaE1D229f9554A676081FD68916e93C8420c9

## Create an Account on Node - Eagle3 (Step 4)
      mkdir eagle3
      cd eagle3
      geth --datadir ./data account new
      enter password
      store public address
      create <eagle3.txt>; open file and enter password; save file
      cd ..

>Created Eagle3(miner) Public Address: 0x406CC1CF7bADb242eF5fC2d64Af68677F36B5fAb

## Configure the Genesis file (Step 5)
*** See https://subtlew3.netlify.app/geth-commands# ***
*** <eaglepoa.json> ***
      
{
      "config": {
      "chainId": 80801,
      "homesteadBlock": 0,
      "eip150Block": 0,
      "eip155Block": 0,
      "eip158Block": 0,
      "byzantiumBlock": 0,
      "constantinopleBlock": 0,
      "petersburgBlock": 0,
      "istanbulBlock": 0,
      "berlinBlock": 0,
      "clique": {
            "period": 30,
            "epoch": 30000
      }
      },
      "difficulty": "1",
      "gasLimit": "8000000",
      "extradata": "0x0000000000000000000000000000000000000000000000000000000000000000168AaBAc0c700eF95269b0876931F6ECbBbbE5970000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      "alloc": {
            "168AaBAc0c700eF95269b0876931F6ECbBbbE597": { "balance": "9000000000000000000000" },
            "c2bdaE1D229f9554A676081FD68916e93C8420c9": { "balance": "9000000000000000000000" },
            "406CC1CF7bADb242eF5fC2d64Af68677F36B5fAb": { "balance": "9000000000000000000000" },
            "d9cAa7ecb5500c5FafcA1F4A954Db75EA34c3361": { "balance": "9000000000000000000000" },
            "A4A19c7b7cAfE09063498F697E647971dC236dca": { "balance": "9000000000000000000000" },
            "E69F4c213c19a6E421869e3a62162f92dDE3050E": { "balance": "9000000000000000000000" },
            "0F97E2dFA64A4ceDcAd9F2Ad5f00578308d73b2e": { "balance": "9000000000000000000000" }
      }
}

## Initializing Nodes (Step 6)
      cd eagle1
      geth --datadir ./data init ../eaglepoa.json
      cd ..
      cd eagle2
      geth --datadir ./data init ../eaglepoa.json
      cd ..
      cd eagle3
      geth --datadir ./data init ../eaglepoa.json
      cd ..

## Start Nodes (Step 7)
### Start Eagle1:
      cd eagle1
      geth --identity Eagle1 --networkid 80801 --datadir ./data --port 30301 --ipcdisable --syncmode "full" --http --allow-insecure-unlock --http.corsdomain "*" --http.addr 0.0.0.0 --http.port 9001 --unlock "0x168AaBAc0c700eF95269b0876931F6ECbBbbE597" --password eagle1.txt --mine console --miner.etherbase  "0x168AaBAc0c700eF95269b0876931F6ECbBbbE597" --authrpc.port 9551 --nodiscover

### Start Eagle2:
      cd eagle2
      geth --identity Eagle2 --networkid 80801 --datadir ./data --port 30301 --ipcdisable --syncmode "full" --http --allow-insecure-unlock --http.corsdomain "*" --http.addr 0.0.0.0 --http.port 9001 --unlock "0xc2bdaE1D229f9554A676081FD68916e93C8420c9" --password eagle2.txt --mine console --miner.etherbase  "0xc2bdaE1D229f9554A676081FD68916e93C8420c9" --authrpc.port 9551 --nodiscover

### Start Eagle3:
      cd eagle3
      geth --identity Eagle3 --networkid 80801 --datadir ./data --port 30301 --ipcdisable --syncmode "full" --http --allow-insecure-unlock --http.corsdomain "*" --http.addr 0.0.0.0 --http.port 9001 --unlock "0x406CC1CF7bADb242eF5fC2d64Af68677F36B5fAb" --password eagle3.txt --mine console --miner.etherbase  "0x406CC1CF7bADb242eF5fC2d64Af68677F36B5fAb" --authrpc.port 9551 --nodiscover

*** To shutdown a node - press ctrl-d or type exit ***

## Get Node Info using command: admin.nodeInfo
>Eagle1 enode: "enode://c382a19c6f53f4ae5f4b6822ac4c6e6eda3d1fa518ec3cbafb7f0f8f6d2fe01b57069b96cc2681e121a5143cbfd43a130c30d7efc896a735ed7cda4cbab51810@172.31.8.171:30301?discport=0"
>Eagle2 enode: "enode://9b604d59b193fe7409931f933e613b55cc575629a5595129f72a0b0731280fb3506580b93f524fb4ada1ba97bbe6fa2b797d64333e54843cea873bdb18f54b72@172.31.8.11:30301?discport=0"
>Eagle3 enode: "enode://f052d11705eb8fcc5515a92fa3eb9ef009f5bac588d3b25804597ed404572a7993e7351d3c0f9bcc02c18745ccfc97a09f9dcc434760b1336b99d4a937f1abe7@172.31.12.109:30301?discport=0"


## Add peer

### Eagle2 -> Eagle1
      admin.addPeer("enode://c382a19c6f53f4ae5f4b6822ac4c6e6eda3d1fa518ec3cbafb7f0f8f6d2fe01b57069b96cc2681e121a5143cbfd43a130c30d7efc896a735ed7cda4cbab51810@172.31.8.171:30301?discport=0")

### Eagle3 -> Eagle1
      admin.addPeer("enode://c382a19c6f53f4ae5f4b6822ac4c6e6eda3d1fa518ec3cbafb7f0f8f6d2fe01b57069b96cc2681e121a5143cbfd43a130c30d7efc896a735ed7cda4cbab51810@172.31.8.171:30301?discport=0")

### List peers
      admin.peers

## Eth Namespace
      eth.accounts
      eth.getBalance("0x168AaBAc0c700eF95269b0876931F6ECbBbbE597")
      eth.getBalance("0xc2bdaE1D229f9554A676081FD68916e93C8420c9")
      eth.getBalance("0x406CC1CF7bADb242eF5fC2d64Af68677F36B5fAb")
      
      eth.getBalance("0xd9cAa7ecb5500c5FafcA1F4A954Db75EA34c3361")

      eth.sendTransaction({from: "0x168AaBAc0c700eF95269b0876931F6ECbBbbE597",to: "0xc2bdaE1D229f9554A676081FD68916e93C8420c9", value: "100000000000000000"})
     
      eth.sendTransaction({from: "0x168AaBAc0c700eF95269b0876931F6ECbBbbE597",to: "0x406CC1CF7bADb242eF5fC2d64Af68677F36B5fAb", value: "100000000000000000"})

      eth.pendingTransactions


# METAMASK
## Add network
>Network name: eaglepoa
>New RPC URL: http://[EC2 Public IP]:9001
>Chain ID: 80801
>Currency symbol: ARMS


