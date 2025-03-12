// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface MintableERC20 {
  function mint(address to, uint256 amount) external;
}

/// This contract is used to mint testnet tokens for testing purposes. IT IS NOT USED IN PRODUCTION.
contract TestnetERC20Faucet {
  MintableERC20 public mockERC20;
  MintableERC20 public mockUSDC;

  constructor(MintableERC20 _mockERC20, MintableERC20 _mockUSDC) {
    mockERC20 = _mockERC20;
    mockUSDC = _mockUSDC;
  }

  /**
   * Mints mockERC20 and mockUSDC to the caller
   */
  function mint() public {
    mockERC20.mint(msg.sender, 15e18);
    mockUSDC.mint(msg.sender, 10e6);
  }
}
