//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ParaToken is ERC20, Ownable {
    uint256 private constant SUPPLY = 10e7 ether;
    uint256 private constant VESTING_PERIOD = 365 days;
    uint256 private constant VESTING_RATE = SUPPLY / VESTING_PERIOD; // amount that vests per second
    uint256 private immutable _start;
    address private immutable _tokenWallet;

    uint256 private _claimed = 0;

    event Claimed(address indexed account, uint256 amount);

    constructor(address tokenWallet) ERC20("Para", "PRA") {
        _start = block.timestamp;
        _tokenWallet = tokenWallet;
        _mint(tokenWallet, 9 * SUPPLY);
    }

    function checkClaim() public view returns (uint256 ret) {
        uint256 elapsedTime = block.timestamp - _start;

        uint256 claim;
        if (elapsedTime >= VESTING_PERIOD) {
            claim = SUPPLY - _claimed;
        } else {
            claim = (VESTING_RATE * elapsedTime) - _claimed;
        }

        return claim;
    }

    function claimOutstanding() external onlyOwner {
        require(_claimed < SUPPLY, "already claimed the supply amount");

        uint256 claim = checkClaim();

        _claimed = _claimed + claim;
        _mint(_tokenWallet, claim);

        emit Claimed(_tokenWallet, claim);
    }
}
