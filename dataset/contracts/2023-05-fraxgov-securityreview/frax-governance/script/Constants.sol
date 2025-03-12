// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

library Constants {
    uint256 internal constant INITIAL_PROPOSAL_THRESHOLD = 100_000e18;
    uint256 internal constant INITIAL_SHORT_CIRCUIT_THRESHOLD = 51;

    address internal constant VE_FXS = 0xc8418aF6358FFddA74e09Ca9CC3Fe03Ca6aDC5b0;

    address internal constant ARBITRUM_TEST_MULTISIG_FINAL4 = 0x8326E59a823F8975664a4BA9d0d9ccf86755c6e3;
    address internal constant ARBITRUM_TEST_MOCK_FXS = 0x6B83c4f3a6729Fb7D5e19b720092162DF439f567;
    address internal constant ARBITRUM_TEST_MOCK_VE_FXS = 0x3Fdb3bd1ab409F0CBB2c4d919b2205ac881B99ED;
}
