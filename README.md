# Description

This repository contains an Ethereum ERC20 token smart contract with a fixed price mechanism. Ideal for simple token transactions at a consistent price.

# Contract Rules

1. Admin Management:
   • Admins have special rights in the contract.
   • Only existing admins can add or remove other admins.
   • The contract deployer (origin) is initially set as the admin.

2. Token Mining and Burning:
   • Mining of new tokens can only be performed by an admin.
   • The contract can burn a specified number of tokens from its supply.

3. Token Price Management:
   • Admins can set a new price for the token in cents.
   • The contract calculates the token price in Wei based on the latest Ethereum price from a Chainlink aggregator.

4. Token Purchase:
   • Users can buy tokens by sending Ether to the contract.
   • Token price is fixed price.
   • The contract calculates the required amount of Ether based on the token price.
   • Tokens are transferred from the contract to the buyer.

5. Admin Allowance Voting:
   • Admins can set an allowance for a specific spender.
   • Allowance votes are used, and a majority vote is required for approval.
   • Admins can reset the allowance for a spender.

6. Withdrawal of Ether:
   • Admins can withdraw Ether from the contract to a specified address.
   • Allowance conditions are checked before withdrawal.

7. Contract Initialization:
   • The contract is initialized with an initial token price, initial token supply, and maximum allowance amount.
   • The contract uses a Chainlink price feed for obtaining real-time Ethereum price data.

8. Fallback and Receive Functions:
   • The contract can receive Ether through both the receive and fallback functions.

# Commands

Compile the code:

`npx hardhat compile`

Deploy sepolia code:

` npx hardhat run --network sepolia  scripts/deploy.js`

ENV file info:

- `INFURA_API_KEY`
- `MNEMONIC`
