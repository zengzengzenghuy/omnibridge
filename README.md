[![Join the chat at https://gitter.im/poanetwork/poa-bridge](https://badges.gitter.im/poanetwork/poa-bridge.svg)](https://gitter.im/poanetwork/poa-bridge?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Build Status](https://github.com/poanetwork/omnibridge/workflows/omnibridge-contracts/badge.svg?branch=master)](https://github.com/poanetwork/omnibridge/workflows/omnibridge-contracts/badge.svg?branch=master)

# Omnibridge Smart Contracts
These contracts provide the core functionality for the Omnibridge AMB extension.

## Testing

The legacy JavaScript/Truffle suite under `test/` is kept as-is. **New tests are
written in Foundry** under `foundry-tests/`.

```sh
yarn install      # required: Foundry resolves OpenZeppelin from node_modules
forge build       # or: yarn forge:build
forge test        # or: yarn forge:test
```

Settings (`solc 0.7.5`, istanbul, optimizer 200) mirror `truffle-config.js`.
OpenZeppelin is pinned to `@openzeppelin/contracts@3.2.2-solc-0.7` via
`remappings.txt`. Foundry test files must declare `pragma abicoder v2;` (required
by forge-std under solc 0.7).

## License

[![License: GPL v3.0](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.



