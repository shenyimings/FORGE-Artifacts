// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./InterfaceManager.sol";

contract OdysslandFeature is Ownable, ERC20 {
    using SafeMath for uint256;

    uint256 public decimal = 10**18;
    uint256 public amountPlayToEarn = 20 * 10**6 * decimal; // 20.000.000 token play to earn
    uint256 public playToEarnReward;
    uint256 internal amountFarm = 10 * 10**6 * decimal;  // 10.000.000 token for farming
    uint256 private farmReward;

    InterfaceManager public manager;

    uint256 public teamToken = 2 * 10**6 * decimal;

    address public teamWallet;
    uint256 public sellFeeRate = 5;
    uint256 public buyFeeRate = 1;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        teamWallet = _msgSender();
    }

    modifier onlyFarmOwners() {
        require(manager.farmOwners(_msgSender()), "Odyssland: caller is not the farmer");
        _;
    }

    modifier onlyEvolver() {
        require(manager.evolvers(_msgSender()), "Odyssland: caller is not the evolver");
        _;
    }

    function setManager(address _manager) public onlyOwner {
        manager = InterfaceManager(_manager);
    }

    function setTransferFeeRate(uint256 _sellFeeRate, uint256 _buyFeeRate)
        public
        onlyOwner
    {
        sellFeeRate = _sellFeeRate;
        buyFeeRate = _buyFeeRate;
    }

    function setMinTokensBeforeSwap(uint256 _teamToken)
        public
        onlyOwner
    {
        require(_teamToken < 20 * 10**6 * decimal);
        teamToken = _teamToken;
    }

    // farm token function for who have farmOwner role
    function farm(address recipient, uint256 amount) external onlyFarmOwners {
        require(amountFarm != farmReward, "Odyssland: Over cap farm");
        require(recipient != address(0), "Odyssland: 0x is not accepted here");
        require(amount > 0, "Odyssland: reward value must be greater than 0");

        farmReward = farmReward.add(amount);
        if (farmReward <= amountFarm) _mint(recipient, amount);
        else {
            uint256 availableReward = farmReward.sub(amountFarm);
            _mint(recipient, availableReward);
            farmReward = amountFarm;
        }
    }

    // play to earn tokens
    function win(address winner, uint256 reward) external onlyEvolver {
        require(playToEarnReward != amountPlayToEarn, "Odyssland: Over cap farm");
        require(winner != address(0), "Odyssland: 0x is not accepted here");
        require(reward > 0, "Odyssland: reward value must be greater than 0");

        playToEarnReward = playToEarnReward.add(reward);
        if (playToEarnReward <= amountPlayToEarn) _mint(winner, reward);
        else {
            uint256 availableReward = playToEarnReward.sub(amountPlayToEarn);
            _mint(winner, availableReward);
            playToEarnReward = amountPlayToEarn;
        }
    }
}