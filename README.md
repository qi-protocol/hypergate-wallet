# Superhack Project

## Hypergate Wallet

TODO

- [x] Init repo (Safe, 4337, Forge, OZ)
- [ ] Implement baseWallet + Safe + SafeGuardian
- [ ] Implement flow diagram
- [ ] Implement ETH - OP L2 execution function
- [ ] Implement OP L2 - ETH execution function
- [ ] Implement OP L2 - OP L2 execution function
- [ ] Create userop test to CrosschainPaymaster
- [ ] Create userop test to AccountEscrow (Only applicable L1-L1 L2-L2)
- [ ] If possible implement route (L2-L1-L2 transaction)
- [ ] Create flattened contracts directory
- [ ] Deploy and verify flattened contracts
- [ ] Write Docs
- [ ] Apply to bounties


## Targeted Bounties:

Optimism is redistributing power to humanity through a low-cost, lightning-fast, Ethereum-equivalent L2 blockchain, OP Mainnet. It’s powered by the OP Stack: a standardized, modular, and open-source dev stack that enables interoperable chains. Together, these underpin the Superchain: a set of chains that all share a software stack and have the same security properties that enable them to communicate and work together.

🏊‍♀️ $5,000 Super Pool Prize
Deploy your app on OP Mainnet and Base and Zora, all three OP Chains in Superhack. The best five (determined by OP Labs) receive $1K each. Testnet deployments are also valid for each chain.



Base is a secure, low-cost, developer-friendly Ethereum-equivalent L2 blockchain built on the OP Stack by Coinbase. Our vision is to collectively work towards an ambitious goal: bring the next billion users onchain. Base is a founding participant in the Optimism Superchain and the second core developer of the OP Stack.

Account Abstraction: $6K
Join us in bringing the next cohort of users onchain. Provide a prototype of account abstraction that helps to simplify the user experience on Base. Deploy a project utilizing a paymaster based on specific user criteria, such as holding an NFT or previous onchain activity. Create a subscription service that is easier to consume and manage by being onchain.


Worldcoin is building the world’s largest identity and financial network as a public utility, giving ownership to everyone. World ID is the protocol to bring global proof of personhood to the internet, built to be privacy-first, decentralized and self-custodial.

ANY


Zora L2 OP Winners
The 10 best projects deployed on Zora Network or built with Zora Protocols, regardless of category, will win a prize of $2,000.


Hyperlane 🥇 Best Use of Permissionless Interoperability: $4k USD
To be eligible for the prize, deploy Hyperlane on your own OP Chain! Give your OP Chain limitless connectivity with Hyperlane. The way you use your new interoperability capabilities will determine your chances of winning the grand prize. You could use Hyperlane to connect your OP Chain with any other and do something amazing! Once you’ve connected your OP Chain, think about creative ways to build an Interchain Application, to leverage Warp Routes, or to create a unique bit of infrastructure. The most technically impressive and creative submission will win the grand prize.

🎼 Best Interchain Application: $2k USD
An interchain application is an application that communicates between different blockchains. It can either transfer assets or make interchain function calls. The winner of this prize will be the most impressive application that makes use of Hyperlane and benefits from its presence on multiple blockchains. This is a perfect opportunity to build a robust DeFi app as a unique OP Chain!


Mode is an OP Stack Layer-2 designed for hyper-growth. The Mode ecosystem is built with integrated tools to support developers with onboarding users and liquidity to grow their applications.

$1000 Prize Pool - distributed among all qualifying submissions 🎱
Build and deploy a project to Mode to qualify for this prize.

$3000 to Best Overall 🥇 Build and deploy an innovative app or tool to Mode. Your project should provide unique functionalities and value-added features to users in the Mode ecosystem.
$2000 to Best Developer Tool 🤝 Build a useful tool for developers on Mode. This can be anything - infrastructure, tools that exist on other chains but not yet on Mode, integrations with existing developer tooling, or libraries that help developers build on Mode.


LayerZero is an open-source protocol for building omnichain, interoperable applications. Powered by lightweight message passing across chains, LayerZero provides authentic and guaranteed message delivery without sacrificing decentralization, efficiency, or scalability.

🚀 Best Omnichain Implementation - $10K
Deploy your app using LayerZero and leverage our permissionless infrastructure, composable omnichain transactions, and immutability to win!


Safe brings digital ownership of accounts to everyone by building universal and open contract standards for the custody of digital assets, data, and identity.
Prizes
Safe will be giving $5,000 in total for the best hacks using Safe{Core}. To be eligible, developers must build with one of the following options:
* Safe{Core} Protocol (integrating or implementing any part of the Protocol). Check this demo app to get an overview of what can be done.
* Safe{Core} Account Abstraction SDK (integrating at least one of the existing kits). Check this demo app to get an overview of what can be done.



Wallet Details

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