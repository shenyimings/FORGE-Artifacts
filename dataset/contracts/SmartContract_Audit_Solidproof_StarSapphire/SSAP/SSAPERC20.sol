// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./ERC20.sol";
import "./Ownable.sol";


contract SSAP is ERC20, Ownable {

    mapping(address => bool) public liquidityPool;
    mapping(address => uint256) public lastTrade;

    uint public sellTax;
    uint public buyTax;
    uint public tradeCooldown;
    address public rewardsPool;
    uint public constant PERCENT_DIVIDER = 1000;
    uint public constant MAX_COOLDOWN = 10 minutes;
    uint public constant MAX_TAX_TRADE = 200;


    event changeTax(uint _sellTax, uint _buyTax);
    event changeCooldown(uint tradeCooldown);
    event changeLiquidityPoolStatus(address lpAddress, bool status);
    event changeWhitelistTax(address _address, bool status);
    event changeRewardsPool(address rewardsPool);

    constructor() ERC20("STAR SAPPHIRE", "SSAP") {
        _mint(msg.sender, 10000000 ether);
        tradeCooldown = 2 minutes;
        sellTax = 150;
        buyTax = 40;
    }

    function setTaxes(uint _sellTax, uint _buyTax) external onlyOwner {
        require(_sellTax <= MAX_TAX_TRADE, "Sell tax must be less than MAX_TAX_TRADE");
        require(_buyTax <= MAX_TAX_TRADE, "Buy tax must be less than MAX_TAX_TRADE");
        sellTax = _sellTax;
        buyTax = _buyTax;
        emit changeTax(_sellTax, _buyTax);
    }

    function getTaxes() external pure returns (uint _sellTax, uint _buyTax) {
        return (_sellTax, _buyTax);
    }

    function setCooldownForTrades(uint _tradeCooldown) external onlyOwner {
        require(_tradeCooldown <= MAX_COOLDOWN, "Cooldown too high");
        tradeCooldown = _tradeCooldown;
        emit changeCooldown(_tradeCooldown);
    }

    function setLiquidityPoolStatus(address _lpAddress, bool _status) external onlyOwner {
        liquidityPool[_lpAddress] = _status;
        emit changeLiquidityPoolStatus(_lpAddress, _status);
    }

    function setRewardsPool(address _rewardsPool) external onlyOwner {
        rewardsPool = _rewardsPool;
        emit changeRewardsPool(_rewardsPool);
    }

    function _transfer(address sender, address receiver, uint256 amount) internal virtual override {
        uint256 taxAmount;

        bool isWhitelisted = receiver ==  owner() || sender == owner();
        if(!isWhitelisted) {
            if(liquidityPool[sender] == true) {
                //It's an LP Pair and it's a buy
                taxAmount = (amount * buyTax) / PERCENT_DIVIDER;
            } else if(liquidityPool[receiver] == true) {          
                //It's an LP Pair and it's a sell
                taxAmount = (amount * sellTax) / PERCENT_DIVIDER;

                require(block.timestamp > lastTrade[sender] + tradeCooldown, "No consecutive sells allowed. Please wait.");
                lastTrade[sender] = block.timestamp;
            }
        }

        if(taxAmount > 0) {
            super._transfer(sender, rewardsPool, taxAmount);
        }    
        super._transfer(sender, receiver, amount - taxAmount);
    }

    function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal override {
        require(_to != address(this), "No transfers to contract allowed.");    
        super._beforeTokenTransfer(_from, _to, _amount);
    }


    fallback() external {
        revert();
    }


}
