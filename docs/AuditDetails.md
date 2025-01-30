# Context

This document refers the information for auditing the contracts.

## File Scope

| File                                                                                                                              |      [nSLOC](# "(nSLOC, nLines, Lines)")      | Description                                                                                                                                                                           | External Dependencies                                                                                                                                                                                                         |
| :-------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| _Contracts (7)_                                                                                                                   |                                               |                                                                                                                                                                                       |                                                                                                                                                                                                                               |
| [contracts/fees/FeeCollectorCore.sol](../contracts/fees/FeeCollectorCore.sol)                                                     |   [25](# "(nSLOC:25, nLines:78, Lines:78)")   | Abstract contract of common logic of MainFeeDistributor and SideChainFeeDistributor                                                                                                   | [`@openzeppelin/*`](https://openzeppelin.com/contracts/)                                                                                                                                                                      |
| [contracts/fees/MainFeeDistributor.sol](../contracts/fees/MainFeeDistributor.sol)                                                 |  [81](# "(nSLOC:81, nLines:181, Lines:181)")  | Main fee distribution contract that will release fees to payees regarding their share                                                                                                 | [`@openzeppelin/*`](https://openzeppelin.com/contracts/)                                                                                                                                                                      |
| [contracts/fees/SideChainFeeDistributor.sol](../contracts/fees/SideChainFeeDistributor.sol)                                       |  [61](# "(nSLOC:61, nLines:128, Lines:128)")  | Side chain fee distribution contract that is able to transfer all fees to the MainFeeDistributor on the main chain using the BridgeableToken contract (Parallel Tunnel) and layerZero | [`@openzeppelin/*`](https://openzeppelin.com/contracts/) [`@layerzerolabs/lz-evm-oapp-v2/contracts/*`](https://github.com/LayerZero-Labs/LayerZero-v2/tree/main/packages/layerzero-v2/evm/oapp)                               |
| [contracts/sPRL/TimeLockPenaltyERC20.sol](../contracts/sPRL/TimeLockPenaltyERC20.sol)                                             | [196](# "(nSLOC:196, nLines:380, Lines:407)") | Base staking contract with time lock and penalties on withdraw. Send penalties amount to the fee receiver defined by accessManager. Commun logic of sPRL1 and sPRL2                   | [`@openzeppelin/*`](https://openzeppelin.com/contracts/)                                                                                                                                                                      |
| [contracts/sPRL/sPRL1.sol](../contracts/sPRL/sPRL1.sol)                                                                           |   [31](# "(nSLOC:31, nLines:62, Lines:62)")   | Single staking contract for PRL                                                                                                                                                       | [`@openzeppelin/*`](https://openzeppelin.com/contracts/)                                                                                                                                                                      |
| [contracts/sPRL/sPRL2.sol](../contracts/sPRL/sPRL2.sol)                                                                           | [179](# "(nSLOC:179, nLines:329, Lines:375)") | Balancer LP staking contract with Aura integration                                                                                                                                    | [`@openzeppelin/*`](https://openzeppelin.com/contracts/), [`@balancer-labs/*`](https://github.com/balancer-labs/balancer-v2-monorepo), [`@aura-finance/*`](https://github.com/aurafinance/aura-contracts/tree/main/contracts) |
| [contracts/rewardMerkleDistributor/RewardMerkleDistributor.sol](../contracts/rewardMerkleDistributor/RewardMerkleDistributor.sol) | [129](# "(nSLOC:129, nLines:248, Lines:248)") | Merkle-based reward distribution contract                                                                                                                                             | [`@openzeppelin/*`](https://openzeppelin.com/contracts/)                                                                                                                                                                      |

## Out of scope

All other files in the repository are out of scope for this audit.

## External imports

- **@openzeppelin/contracts/access/AccessManaged.sol**
  - [contracts/fees/FeeCollectorCore.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/FeeCollectorCore.sol)
  - [contracts/fees/MainFeeDistributor.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/MainFeeDistributor.sol)
  - [contracts/fees/SideChainFeeCollector.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/SideChainFeeCollector.sol)
  - [contracts/sPRL/TimeLockPenaltyERC20.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/TimeLockPenaltyERC20.sol)
  - [contracts/rewardMerkleDistributor/RewardMerkleDistributor.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/rewardMerkleDistributor/RewardMerkleDistributor.sol)
- **@openzeppelin/contracts/token/ERC20/IERC20.sol**
  - [contracts/fees/FeeCollectorCore.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/FeeCollectorCore.sol)
  - [contracts/fees/MainFeeDistributor.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/MainFeeDistributor.sol)
  - [contracts/fees/SideChainFeeCollector.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/SideChainFeeCollector.sol)
  - [contracts/rewardMerkleDistributor/RewardMerkleDistributor.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/rewardMerkleDistributor/RewardMerkleDistributor.sol)
  - [contracts/sPRL/TimeLockPenaltyERC20.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/TimeLockPenaltyERC20.sol)
  - [contracts/sPRL/sPRL1.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/sPRL1.sol)
  - [contracts/sPRL/sPRL2.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/sPRL2.sol)
- **@openzeppelin/contracts/token/ERC20/ERC20.sol**
  - [contracts/sPRL/TimeLockPenaltyERC20.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/TimeLockPenaltyERC20.sol)
  - [contracts/sPRL/sPRL1.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/sPRL1.sol)
  - [contracts/sPRL/sPRL2.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/sPRL2.sol)
- **@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol**
  - [contracts/fees/FeeCollectorCore.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/FeeCollectorCore.sol)
  - [contracts/fees/MainFeeDistributor.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/MainFeeDistributor.sol)
  - [contracts/fees/SideChainFeeCollector.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/SideChainFeeCollector.sol)
  - [contracts/rewardMerkleDistributor/RewardMerkleDistributor.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/rewardMerkleDistributor/RewardMerkleDistributor.sol)
  - [contracts/sPRL/TimeLockPenaltyERC20.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/TimeLockPenaltyERC20.sol)
  - [contracts/sPRL/sPRL2.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/sPRL2.sol)
- **@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol**
  - [contracts/sPRL/TimeLockPenaltyERC20.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/TimeLockPenaltyERC20.sol)
  - [contracts/sPRL/sPRL2.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/sPRL2.sol)
- **@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol**
  - [contracts/sPRL/TimeLockPenaltyERC20.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/TimeLockPenaltyERC20.sol)
  - [contracts/sPRL/sPRL1.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/sPRL1.sol)
  - [contracts/sPRL/sPRL2.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/sPRL2.sol)
- **@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol**
  - [contracts/sPRL/sPRL1.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/sPRL1.sol)
  - [contracts/sPRL/sPRL2.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/sPRL2.sol)
- **@openzeppelin/contracts/utils/Pausable.sol**
  - [contracts/fees/FeeCollectorCore.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/FeeCollectorCore.sol)
  - [contracts/fees/MainFeeDistributor.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/MainFeeDistributor.sol)
  - [contracts/fees/SideChainFeeCollector.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/SideChainFeeCollector.sol)
  - [contracts/rewardMerkleDistributor/RewardMerkleDistributor.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/rewardMerkleDistributor/RewardMerkleDistributor.sol)
  - [contracts/sPRL/TimeLockPenaltyERC20.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/TimeLockPenaltyERC20.sol)
  - [contracts/sPRL/sPRL1.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/sPRL1.sol)
  - [contracts/sPRL/sPRL2.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/sPRL2.sol)
- **@openzeppelin/contracts/utils/ReentrancyGuard.sol**
  - [contracts/fees/FeeCollectorCore.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/FeeCollectorCore.sol)
  - [contracts/fees/MainFeeDistributor.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/MainFeeDistributor.sol)
  - [contracts/fees/SideChainFeeCollector.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/SideChainFeeCollector.sol)
  - [contracts/rewardMerkleDistributor/RewardMerkleDistributor.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/rewardMerkleDistributor/RewardMerkleDistributor.sol)
  - [contracts/sPRL/TimeLockPenaltyERC20.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/TimeLockPenaltyERC20.sol)
- **@openzeppelin/contracts/utils/cryptography/MerkleProof.sol**
  - [contracts/rewardMerkleDistributor/RewardMerkleDistributor.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/rewardMerkleDistributor/RewardMerkleDistributor.sol)
- **@openzeppelin/contracts/utils/Nonces.sol**
  - [contracts/sPRL/sPRL1.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/sPRL1.sol)
  - [contracts/sPRL/sPRL2.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/sPRL2.sol)
- **@openzeppelin/contracts/utils/Address.sol**
  - [contracts/sPRL/sPRL2.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/sPRL/sPRL2.sol)
- **@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol**
  - [contracts/fees/SideChainFeeCollector.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/SideChainFeeCollector.sol)
- **@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol**
  - [contracts/fees/SideChainFeeCollector.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/SideChainFeeCollector.sol)
- **@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCore.sol**
  - [contracts/fees/SideChainFeeCollector.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/SideChainFeeCollector.sol)
- **@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol**
  - [contracts/fees/SideChainFeeCollector.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/SideChainFeeCollector.sol)
- **@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol**
  - [contracts/fees/SideChainFeeCollector.sol](https://github.com/parallel-protocol/tokenomics/blob/main/contracts/fees/SideChainFeeCollector.sol)

## Additional context

Read the [Technical Specs](./TechnicalSpecs.md) for more context.

## Scoping Details

```text
- If you have a public code repo, please share it here: n/a
- How many contracts are in scope?: 8
- Total SLoC for these contracts?: 940
- How many external imports are there?: 17
- How many separate interfaces and struct definitions are there for the contracts within scope?: 7 interfaces, 6 structs
- Does most of your code generally use composition or inheritance?: inheritance
- How many external calls?: 4 (Balancer Vault, Aura Booster, Aura Vault, WETH)
- What is the overall line coverage percentage provided by your tests?: 93.8%
- Is there a need to understand a separate part of the codebase / get context in order to audit this part of the protocol?: Yes
- Please describe required context: Understanding of Balancer V3 vaults, Aura staking mechanisms and LayerZero
- Does it use an oracle?: No
- Does the token conform to the ERC20 standard?: Yes
- Are there any novel or unique curve logic or mathematical models?: Yes
- Does it use a timelock function?: Yes, for sPRL withdrawals
- Is it an NFT?: No
- Does it have an AMM?: Uses Balancer V3
- Is it a fork of a popular project?: No
- Does it use rollups?: No
- Is it multi-chain?: Yes
- Does it use a side-chain?: Yes
```

## Audit Notes

### Auctioneer contract removed

Auctioneer contract has been removed from the protocol as `Issue_10: Auctioneer only works well with gradual fees` could
significantly impact the protocol revenue. We will then send the fees to the DAO treasury that will proceed with OTC
swaps.

## Tests

The contracts are tested using the Hardhat framework with additional testing utilities.

### Run tests

```bash
bun run test
```

### Run Coverage

```bash
bun run test:coverage:report
```
