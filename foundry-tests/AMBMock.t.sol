// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.5;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../contracts/mocks/AMBMock.sol";

// Smoke test proving the Foundry harness compiles and runs against the real
// project contracts under solc 0.7.5.
contract AMBMockTest is Test {
    AMBMock amb;

    function setUp() public {
        amb = new AMBMock();
    }

    function test_maxGasPerTx() public {
        assertEq(amb.maxGasPerTx(), 1000000);
    }

    function test_sourceChainId() public {
        assertEq(amb.sourceChainId(), 1337);
    }
}
