//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../interfaces/IPAN.sol";

contract Minter is Ownable, ReentrancyGuard {
    using SafeERC20 for IPAN;

    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    mapping (address => bool) private operators;
    uint256 public PANPerBlock;
    uint256 public lastMinted;
    IPAN public PAN;

    modifier onlyOperators() {
        require(operators[msg.sender] == true, "Minter: caller is not the operators");
        _;
    }

    constructor (IPAN _PAN, uint256 _PANPerBlock, uint256 _startMint) {
        PANPerBlock = _PANPerBlock;
        PAN = _PAN;
        lastMinted = _startMint;
    }

    function update() public {
        if (block.number > lastMinted) {
            uint256 _amount = (block.number - lastMinted) * PANPerBlock;
            PAN.mint(address(this), _amount);
            lastMinted = block.number;
        }
    }

    function transfer(address _to, uint256 _amount) external onlyOperators nonReentrant {
        if (_amount >= PAN.balanceOf(address(this))) {
            update();
        }
        require(_amount <= PAN.balanceOf(address(this)), 'Minter: not enough PAN');
        PAN.safeTransfer(_to, _amount);
    }
}