# Overview

This repository contains the source code for contracts and testing suites for all of Parallel's tokenomics architecture.

## Repository Structure

- [Broadcast](./broadcast) folder contains Foundry transactions executed by scripts.
- [Contracts](./contracts) folder contains contracts source code.
- [Deploy](./deploy) folder contains hardhat deployment scripts.
- [Deployments](./deployments) folder contains info of contracts deployed per network.
- [Docs](./docs) folder contains all documentation related to main contracts.
- [Script](./scripts) folder contains Foundry scripts to interact with onchain contracts.
- [Test](./test) folder contains all tests related to the contracts with mocks and settings.
- [Utils](./utils) folder contains helper functions.

## Getting Started

### Foundry

Foundry is used for testing and scripting. To
[Install foundry follow the instructions.](https://book.getfoundry.sh/getting-started/installation)

### Install js dependencies

```bash
bun i
```

### Fill the `.env` file with your data

The Foundry script relies solely on the PRIVATE_KEY. The MNEMONIC is used on the Hardhat side and will override the
PRIVATE_KEY if it is defined.

```bash
export API_KEY_ALCHEMY="YOUR_API_KEY_ALCHEMY"
export API_KEY_ETHERSCAN="YOUR_API_KEY_ETHERSCAN"
export API_KEY_POLYGONSCAN="YOUR_API_KEY_POLYGONSCAN"
export MNEMONIC="YOUR_MNEMONIC"
export PRIVATE_KEY="YOUR_PRIVATE_KEY"
export FOUNDRY_PROFILE="default"
```

### Compile contracts

```bash
bun run compile
```

### Run tests

```bash
bun run test
```

You will find other useful commands in the [package.json](./package.json) file.

## Licences

All contracts is under the `MIT` License, see [`LICENSE`](./LICENSE).
