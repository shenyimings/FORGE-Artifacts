// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "src/interfaces/INETH.sol";

contract NETH is INETH, ERC20, Ownable {
    address public liquidStakingContract;

    modifier onlyLiquidStaking() {
        require(liquidStakingContract == msg.sender, "Not allowed to touch funds");
        _;
    }

    constructor() ERC20("Node ETH", "nETH") {}

    function setLiquidStaking(address _liquidStaking) public onlyOwner {
        liquidStakingContract = _liquidStaking;
    }

    function whiteListMint(uint256 amount, address account) external onlyLiquidStaking {
        _mint(account, amount);
    }

    function whiteListBurn(uint256 amount, address account) external onlyLiquidStaking {
        _burn(account, amount);
    }
}
