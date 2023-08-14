# **Hypergate Wallet**: The Ultimate Hyper-Crosschain Wallet Solution 🚀

Imagine a future where your grandma uses crypto to buy her favorite cookies, and she doesn't even realize it's powered by blockchain. Sounds like sci-fi, right? 🌌

**Is this achievable?**  
Absolutely! But let's be real, we're still paving the yellow brick road to that future.

## **Where Are We Now?** 🌍
We're surrounded by a myriad of L1s, innovative L1-L2 scaling solutions, and the budding world of ERC4337 (account abstraction). It's like being in a candy store with endless choices!

**But here's the twist:**  
1. 🌀 Interoperability is possible, but having a smooth chat between chains feels like trying to order a pizza in a language you don't speak. And if you want to make a move from your wallet to another chain? You better be ready for some bridge-trekking!
2. 🚀 Thinking one EVM blockchain can do it all? Remember the skyrocketing gas prices of Ethereum Mainnet in 2021? That's like expecting a single superhero to save the world every time. Different chains have their strengths, and it's all about leveraging them.
3. 🌉 But, there's a catch! While we can shout across chains, it's like yelling across a canyon. If your money's on one side and you want to make magic on the other, you're in for a hike. Especially if you're into minting those shiny NFTs.

## **Enter Hypergate Wallet** 🌟
It's not just another wallet. Think of it as your personal crypto wizard 🧙‍♂️. It's a crosschain account abstraction wallet control system (phew, that's a mouthful!).

**What's the magic?**  
- ✨ Users craft their own wallets, sprinkling in features as they like.  
- ✨ Our system lets you whip up your own transactions. It's like baking – but instead of adding chocolate chips or nuts, you're adding hooks and controls.  
- ✨ And the cherry on top? Our special crosschain paymaster system. It's like having a genie granting wishes on where, how, and from where you execute transactions.

**In a nutshell:** Hypergate Wallet is your ticket to a seamless, chain-agnostic crypto experience. So, are you ready to jump into the future? 🚀

Submission to ETH Global Superhack 2023 (Aug 11~13):

[Project showcase](https://ethglobal.com/showcase/hypergate-wallet-h1esy)

[Github Repository](https://github.com/qi-protocol/eth-superhack)

TODO

- [x] Init repo (Safe, 4337, Forge, OZ)
- [x] Implement baseWallet + Safe + SafeGuardian
- [x] Implement flow diagram L1-L1
- [x] Implement flow diagram L2-L1
- [x] Implement flow diagram L1-L2
- [x] Implement flow diagram L2-L1-L1-L2
- [x] Implement Infra diagram
- [x] Implement ETH - ETH execution function
- [x] Implement Test: Wallet Generation
- [ ] Implement Test: TestEscrow HandleMessage
- [ ] Implement Test: TestEscrow PrintOp
- [ ] Implement Test: TestEscrow CallPrintOp
- [ ] Implement ETH - OP L2 execution function
- [ ] Implement OP L2 - ETH execution function
- [ ] Implement OP L2 - OP L2 execution function
- [ ] Create script to test 
- [ ] Create userop test to CrosschainPaymaster
- [ ] Create userop test to AccountEscrow (Only applicable L1-L1 L2-L2)
- [ ] If possible implement route (L2-L1-L2 transaction)
- [ ] Create flattened contracts directory
- [ ] Deploy and verify flattened contracts
- [x] Write Docs




forge script script/deploy.s.sol:Deploy --broadcast --rpc-url https://still-orbital-theorem.base-goerli.quiknode.pro/7778efb6a98a8757645ed9ead407fd614d3964b9/




### Wallet Details

| Wallet      | Code       |
| ----------- | ---------- |
| Safe        | 1          |

| Safe Type   | Code       |
| ----------- | ---------- |
| Default     | 0x01       |

### DB Format

| public key                                 | nonce        | wallet    | type      |
| ------------------------------------------ | ------------ | --------- | --------- |
| 0xfF65689a4AEB6EaDd18caD2dE0022f8Aa18b67de | 0            | 1         | 0x1       |