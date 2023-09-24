# eaglepoa

## Create an eaglepoa (Step 1)
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

>Created Eagle1 Public Address: 0x954147177c89b1cC9f1cd5751352b798832CDAA5

## Create an Account on Node - Eagle2 (Step 3)
      mkdir eagle2
      cd eagle2
      geth --datadir ./data account new
      enter password
      store public address
      create <eagle2.txt>; open file and enter password; save file
      cd ..

>Created Eagle2 Public Address: 0x51FC9578B9688a861d494ad309B825037C616Eb3

## Create an Account on Node - Eagle3 (Step 4)
      mkdir eagle3
      cd eagle3
      geth --datadir ./data account new
      enter password
      store public address
      create <eagle3.txt>; open file and enter password; save file
      cd ..

>Created Eagle3 Public Address: 0x4352b4d7317810Bd0e1Cc71776c597f3978b0837

## Configure the Genesis file (Step 5)
*** See https://subtlew3.netlify.app/geth-commands# ***
*** <eaglepoa.json> ***
      ```
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
            "extradata": "0x0000000000000000000000000000000000000000000000000000000000000000954147177c89b1cC9f1cd5751352b798832CDAA50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            "alloc": {
                  "954147177c89b1cC9f1cd5751352b798832CDAA5": { "balance": "9000000000000000000000" },
                  "51FC9578B9688a861d494ad309B825037C616Eb3": { "balance": "0" },
                  "4352b4d7317810Bd0e1Cc71776c597f3978b0837": { "balance": "0" }
            }
      }
      ```

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
      geth --identity Eagle1 --networkid 80801 --datadir ./data --port 30301 --ipcdisable --syncmode "full" --http --allow-insecure-unlock --http.corsdomain "*" --http.addr 0.0.0.0 --http.port 9001 --unlock "0x954147177c89b1cC9f1cd5751352b798832CDAA5" --password eagle1.txt --mine console --miner.etherbase  "0x954147177c89b1cC9f1cd5751352b798832CDAA5" --authrpc.port 9551 --nodiscover

### Start Eagle2:
      cd eagle2
      geth --identity Eagle2 --networkid 80801 --datadir ./data --port 30302 --ipcdisable --syncmode "full" --http --allow-insecure-unlock --http.corsdomain "*" --http.addr 0.0.0.0 --http.port 9002 --unlock "0x51FC9578B9688a861d494ad309B825037C616Eb3" --password eagle2.txt console --authrpc.port 9552 --nodiscover

### Start Eagle3:
      cd eagle3
      geth --identity Eagle3 --networkid 80801 --datadir ./data --port 30303 --ipcdisable --syncmode "full" --http --allow-insecure-unlock --http.corsdomain "*" --http.addr 0.0.0.0 --http.port 9003 --unlock "0x4352b4d7317810Bd0e1Cc71776c597f3978b0837" --password eagle3.txt console --authrpc.port 9553 --nodiscover

*** To shutdown a node - press ctrl-d or type exit ***

## Get Node Info using command: admin.nodeInfo
>Eagle1 enode: "enode://e5c9483ec8a7fcb241ffb0def32801fdd2d07b4dab8f844d9a2830ef68fc2842aeba4376761889a793010da371c352f37c9ddff9abf1d169596ae2e6d645c043@76.198.155.151:30301"
>Eagle2 enode: "enode://87616eea8dd76e0610016b3272d6caf578809ecd5605608c0bf69d73a3116f158b1004222bc595066be89c9531f8cc6a5bf48bf2323a7e99c14b97234914f8b4@76.198.155.151:30302"
>Eagle3 enode: "enode://10ded92200d8a07814a17b0da94d5fcefba1f56f6e04115c1f575837ed3f6edd62dccad4b897818fca7170ccf517505891bee863f28c33216212eec7b494f5c9@76.198.155.151:30303"


## Add peer

### Eagle2 -> Eagle1
      admin.addPeer("enode://e5c9483ec8a7fcb241ffb0def32801fdd2d07b4dab8f844d9a2830ef68fc2842aeba4376761889a793010da371c352f37c9ddff9abf1d169596ae2e6d645c043@76.198.155.151:30301")

### Eagle3 -> Eagle1
      admin.addPeer("enode://e5c9483ec8a7fcb241ffb0def32801fdd2d07b4dab8f844d9a2830ef68fc2842aeba4376761889a793010da371c352f37c9ddff9abf1d169596ae2e6d645c043@76.198.155.151:30301")

### List peers
      admin.peers

## Eth Namespace
      eth.accounts
      eth.getBalance("0x954147177c89b1cC9f1cd5751352b798832CDAA5")
      eth.getBalance("0x51FC9578B9688a861d494ad309B825037C616Eb3")
      eth.getBalance("0x4352b4d7317810Bd0e1Cc71776c597f3978b0837")
      
      eth.getBalance("0xA0823e19BB2580Bf0181550e731dFc2D71aE0186")

      eth.sendTransaction({from: "0x954147177c89b1cC9f1cd5751352b798832CDAA5",to: "0x51FC9578B9688a861d494ad309B825037C616Eb3", value: "100000000000000000"})
     
      eth.sendTransaction({from: "0x954147177c89b1cC9f1cd5751352b798832CDAA5",to: "0x4352b4d7317810Bd0e1Cc71776c597f3978b0837", value: "100000000000000000"})

      eth.pendingTransactions


# METAMASK
## Add network
>Network name: eaglepoa
>New RPC URL: http://[EC2 Public IP]:9001
>Chain ID: 80801
>Currency symbol: ARMS


