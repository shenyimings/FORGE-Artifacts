//SPDX-License-Identifier: Huralya
pragma solidity 0.8.23;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable2Step.sol';

contract Huralya is ERC20, Ownable2Step {
  uint256 public constant MINT_INTERVAL = 365 days * 4;

  uint256 public constant MAX_SUPPLY = 200_000_000 * 10 ** 6;

  uint256 public MINT_TIMESTAMP;

  uint256 public MINTED_AMOUNT = 0;

  constructor() ERC20('Huralya', 'LYA') {
    MINT_TIMESTAMP = block.timestamp + MINT_INTERVAL;
    MINTED_AMOUNT += 100_000_000 * 10 ** 6;
    _mint(owner(), 100_000_000 * 10 ** 6);
  }

  function burn(uint256 _amount) external {
    super._burn(msg.sender, _amount);
  }

  function mint(uint256 _amount) external onlyOwner {
    require(
      block.timestamp >= MINT_TIMESTAMP,
      'LYA: Minting is not allowed yet, please wait until the next minting interval'
    );
    require(
      MINTED_AMOUNT + _amount <= MAX_SUPPLY,
      'LYA: Maximum supply reached, no more tokens can be minted'
    );
    MINTED_AMOUNT += _amount;
    super._mint(owner(), _amount);
  }

  function remainingMintableAmount() external view returns (uint256) {
    return MAX_SUPPLY - MINTED_AMOUNT;
  }

  function decimals() public view virtual override returns (uint8) {
    return 6;
  }
}
