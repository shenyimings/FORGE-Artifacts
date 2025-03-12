pragma solidity 0.6.12;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NinjaToken is ERC20("NinjaSwap", "NINJA"), Ownable {
    using SafeMath for uint256;

    address public AMO;
    address public MasterChef;
    uint256 public masterChefWallet;
    uint256 public AMOMinted;
    uint256 public masterChefMinted;

    constructor(address _ninjaBounty) public {
       _mint(_ninjaBounty, 200000000000000000000000);  //mint 200k for airdrop and bounty
    }
    function mint(address _to, uint256 _amount) public onlyMinter {
        if (msg.sender == MasterChef) {
            masterChefMinted = masterChefMinted.add(_amount);
             _mint(_to, _amount);
        }
        if (msg.sender == AMO) {
            AMOMinted = AMOMinted.add(_amount);
             _mint(_to, _amount);
        }
    }

    function addRewardMWallet(uint256 _newReward) public onlyMinter {
        masterChefWallet = masterChefWallet.add(_newReward);
    }
    function updateMasterChef(address _masterChef) public onlyOwner {
        MasterChef = _masterChef;
    }
    function updateAMO(address _AMO) public onlyOwner {
        AMO = _AMO;
    }

    //only masterChef and AMO can mint
    modifier onlyMinter() {
        require(
            AMO == msg.sender || MasterChef == msg.sender,
            "No Permission"
        );
        _;
    }
}
